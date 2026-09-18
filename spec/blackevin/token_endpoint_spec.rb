# frozen_string_literal: true

RSpec.describe Blackevin::TokenEndpoint do
  let(:rest) { Blackevin::Rest.new(key: "ck_test_5f2c8a1e9b.k25b5a4") }

  def env(method = "GET", extra = {})
    {"REQUEST_METHOD" => method, "PATH_INFO" => "/"}.merge(extra)
  end

  it "answers a signed TokenRequest for whoever the block identifies" do
    endpoint = described_class.new(rest: rest) do |rack_env|
      {client_id: rack_env.fetch("app.user_id"), capability: {"room:1" => %w[subscribe]}}
    end

    status, headers, body = endpoint.call(env("GET", "app.user_id" => 7))
    payload = JSON.parse(body.join)

    expect(status).to eq(200)
    expect(headers).to include("content-type" => "application/json", "cache-control" => "no-store")
    expect(payload).to include("keyName" => "k25b5a4", "clientId" => "7", "capability" => '{"room:1":["subscribe"]}')
    expect(payload.fetch("mac")).to eq(Blackevin::TokenRequest.from_h(payload).sign("ck_test_5f2c8a1e9b").mac)
  end

  it "accepts string keys from the block" do
    endpoint = described_class.new(rest: rest) { {"client_id" => "bob"} }

    expect(JSON.parse(endpoint.call(env("POST")).last.join)).to include("clientId" => "bob")
  end

  it "answers 401 when the block identifies nobody, and signs nothing" do
    endpoint = described_class.new(rest: rest) { nil }

    status, _, body = endpoint.call(env)

    expect(status).to eq(401)
    expect(JSON.parse(body.join)).to eq("error" => "unauthorized")
  end

  it "answers 405 to anything but GET and POST" do
    status, headers, = described_class.new(rest: rest) { {} }.call(env("DELETE"))

    expect(status).to eq(405)
    expect(headers["allow"]).to eq("GET, POST")
  end

  it "falls back to Blackevin.rest, resolved per request" do
    endpoint = described_class.new { {client_id: "bob"} }

    Blackevin.configure { |config| config.key = "secret.late" }

    expect(JSON.parse(endpoint.call(env).last.join)).to include("keyName" => "late")
  end

  it "needs the block" do
    expect { described_class.new }.to raise_error(ArgumentError)
  end
end
