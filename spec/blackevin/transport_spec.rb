# frozen_string_literal: true

RSpec.describe Blackevin::Transport do
  it "puts the percent-encoded path, the headers and the body on the wire unchanged" do
    server = TinyServer.new(body: '{"channel":"a b","published":true}')
    rest = Blackevin::Rest.new(key: "secret.kid", rest_endpoint: server.url)

    expect(rest.channels.get("team/a b:ação").publish("greeting", {"text" => "olá"})).to be(true)

    server.close

    expect(server.received).to start_with("POST /api/channels/team%2Fa%20b%3Aa%C3%A7%C3%A3o/publish HTTP/1.1\r\n")
    expect(server.received).to match(/^authorization: Basic c2VjcmV0LmtpZA==\r$/i)
    expect(server.received).to match(/^content-type: application\/json\r$/i)
    expect(server.received).to match(/^user-agent: blackevin-ruby\//i)
    expect(server.received.force_encoding("UTF-8")).to end_with('{"name":"greeting","data":{"text":"olá"}}')
  end

  it "raises the server's sentence on a refusal" do
    server = TinyServer.new(status: 429, body: '{"error":"queue limit reached (3)","reason":"queue_limit"}')
    rest = Blackevin::Rest.new(key: "secret.kid", rest_endpoint: server.url)

    expect { rest.queues.upsert(name: "inbox") }.to raise_error(Blackevin::Error) do |error|
      expect(error.message).to eq("upsert queue failed: queue limit reached (3)")
      expect(error.reason).to eq("queue_limit")
      expect(error).to be_quota
    end

    server.close
  end

  it "turns a refused connection into a ConnectionError, not a bare Errno" do
    server = TinyServer.new
    url = server.url

    server.close

    expect { Blackevin::Rest.new(key: "secret.kid", rest_endpoint: url).channels.get("room").history }
      .to raise_error(Blackevin::ConnectionError, /could not reach 127\.0\.0\.1/)
  end

  it "turns a read timeout into a ConnectionError" do
    server = TinyServer.new(delay: 1)
    rest = Blackevin::Rest.new(key: "secret.kid", rest_endpoint: server.url, read_timeout: 0.1)

    expect { rest.channels.get("room").history }.to raise_error(Blackevin::ConnectionError, /Timeout/)

    server.close
  end

  it "is a Blackevin::Error, so one rescue covers both" do
    expect(Blackevin::ConnectionError.ancestors).to include(Blackevin::Error)
    expect(Blackevin::ConnectionError.new("x").status_code).to be_nil
  end
end
