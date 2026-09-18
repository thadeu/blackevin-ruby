# frozen_string_literal: true

require "uri"

RSpec.describe "the language-neutral contract" do
  def symbolize(params)
    params.to_h do |key, value|
      [key.gsub(/([A-Z])/) { "_#{$1.downcase}" }.to_sym, value]
    end
  end

  describe "token-request" do
    ContractFixtures.load("token-request").fetch("cases").each do |example|
      it example.fetch("name") do
        rest = Blackevin::Rest.new(key: example.fetch("key"))

        request = rest.auth.create_token_request(**symbolize(example.fetch("params")))

        expect(request.signing_text).to eq(example.dig("expected", "signingText"))
        expect(request.to_h).to eq(example.dig("expected", "request"))
        expect(JSON.parse(request.to_json)).to eq(example.dig("expected", "request"))
      end
    end

    ContractFixtures.load("token-request").fetch("signing").each do |example|
      it "signing alone: #{example.fetch("name")}" do
        request = Blackevin::TokenRequest.from_h(example.fetch("request")).sign(example.fetch("secret"))

        expect(request.signing_text).to eq(example.dig("expected", "signingText"))
        expect(request.mac).to eq(example.dig("expected", "mac"))
      end
    end

    it "fills ttl, capability and a 32 hex character nonce when none is given" do
      defaults = contract("token-request").fetch("defaults")

      request = Blackevin::Rest.new(key: "secret.kid").auth.create_token_request

      expect(request.ttl).to eq(defaults.fetch("ttl"))
      expect(request.capability).to eq(defaults.fetch("capability"))
      expect(request.nonce).to match(/\A\h{#{defaults.fetch("nonceHexChars")}}\z/o)
      expect(request.timestamp).to be_within(5_000).of((Time.now.to_f * 1000).to_i)
    end
  end

  describe "api-key" do
    ContractFixtures.load("api-key").fetch("valid").each do |example|
      it "splits: #{example.fetch("name")}" do
        key = Blackevin::ApiKey.parse(example.fetch("key"))

        expect(key.key_name).to eq(example.fetch("keyName"))
        expect(key.secret).to eq(example.fetch("secret"))
      end
    end

    ContractFixtures.load("api-key").fetch("invalid").each do |example|
      it "refuses: #{example.fetch("name")}" do
        expect { Blackevin::ApiKey.parse(example.fetch("key")) }.to raise_error(Blackevin::ConfigurationError)
        expect { Blackevin::Rest.new(key: example.fetch("key")).auth.create_token_request }
          .to raise_error(Blackevin::ConfigurationError)
      end
    end
  end

  describe "authorization" do
    ContractFixtures.load("authorization").fetch("cases").each do |example|
      it example.fetch("name") do
        rest = Blackevin::Rest.new(**symbolize(example.fetch("options")))

        expect(rest.authorization_header).to eq(example.fetch("header"))
      end
    end
  end

  describe "endpoints" do
    ContractFixtures.load("endpoints").fetch("cases").each do |example|
      it example.fetch("name") do
        resolved = Blackevin::Endpoints.resolve(**symbolize(example.fetch("options")), env: example.fetch("env"))

        expect(resolved.endpoint).to eq(example.fetch("endpoint"))
        expect(resolved.rest_endpoint).to eq(example.fetch("restEndpoint"))
      end
    end
  end

  describe "errors" do
    ContractFixtures.load("errors").fetch("cases").each do |example|
      it example.fetch("name") do
        error = Blackevin::Error.from_response(example.fetch("what"), example.fetch("status"), example.fetch("body"))

        expect(error.message).to eq(example.fetch("message"))
        expect(error.status_code).to eq(example.fetch("statusCode"))
        expect(error.reason).to eq(example.fetch("reason"))
        expect(error.quota?).to eq(example.fetch("isQuota"))
      end
    end
  end

  describe "rest-requests" do
    spec = ContractFixtures.load("rest-requests")

    def perform(rest, example)
      args = example.fetch("args")

      case example.fetch("operation")
      when "channel.publish" then rest.channels.get(example.fetch("channel")).publish(args["name"], args["data"])
      when "channel.history" then rest.channels.get(example.fetch("channel")).history(**symbolize(args))
      when "channel.presence.get" then rest.channels.get(example.fetch("channel")).presence.get
      when "auth.requestToken" then rest.auth.request_token(args)
      else raise "the fixture names an operation this SDK does not map: #{example.fetch("operation")}"
      end
    end

    def wire(value)
      case value
      when Array then value.map { |item| wire(item) }
      when Blackevin::TokenDetails then value.to_h
      when Struct then value.to_h.to_h { |key, item| [key.to_s.gsub(/_([a-z])/) { $1.upcase }, item] }.compact
      when true then nil
      else value
      end
    end

    spec.fetch("cases").each do |example|
      it example.fetch("name") do
        transport = RecordingTransport.new(
          status: example.dig("response", "status"),
          body: example.dig("response", "body")
        )
        rest = Blackevin::Rest.new(key: spec.fetch("key"), rest_endpoint: spec.fetch("restEndpoint"), transport: transport)

        if example["raises"]
          expect { perform(rest, example) }.to raise_error(Blackevin::Error) do |error|
            expect(error.message).to eq(example.dig("raises", "message"))
            expect(error.status_code).to eq(example.dig("raises", "statusCode"))
            expect(error.reason).to eq(example.dig("raises", "reason"))
          end
        else
          expect(wire(perform(rest, example))).to eq(example.fetch("returns"))
        end

        expect(transport.requests.size).to eq(1)

        sent = transport.last
        expected = example.fetch("request")
        uri = URI.parse(sent.url)

        expect(sent.method).to eq(expected.fetch("method"))
        expect("#{uri.scheme}://#{uri.host}").to eq(spec.fetch("restEndpoint"))
        expect(uri.path).not_to include("+")
        expect(URI.decode_www_form_component(uri.path)).to eq(expected.fetch("pathDecoded"))
        expect(uri.path).to eq(expected.fetch("path"))
        expect(URI.decode_www_form(uri.query.to_s).to_h).to eq(expected.fetch("query", {}))

        expect(sent.headers["authorization"]).to eq(expected.dig("headers", "authorization") ? spec.fetch("authorization") : nil)
        expect(sent.headers["content-type"]).to eq(expected.dig("headers", "content-type"))

        if expected.fetch("body").nil?
          expect(sent.body).to be_nil
        else
          body = JSON.parse(sent.body)

          expected.fetch("bodyNullableKeys", []).each { |key| body.delete(key) if body[key].nil? }

          expect(body).to eq(expected.fetch("body"))
        end
      end
    end
  end

  describe "capability" do
    it "serialises a map compactly, in insertion order, as the fixtures sign it" do
      rest = Blackevin::Rest.new(key: "secret.kid")

      request = rest.auth.create_token_request(capability: {zeta: %w[publish subscribe], alpha: %w[history]})

      expect(request.capability).to eq('{"zeta":["publish","subscribe"],"alpha":["history"]}')
    end
  end
end
