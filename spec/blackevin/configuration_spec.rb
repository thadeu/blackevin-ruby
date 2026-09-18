# frozen_string_literal: true

RSpec.describe Blackevin do
  around do |example|
    saved = ENV.to_h.slice('BLACKEVIN_KEY', 'BLACKEVIN_REST_ENDPOINT', 'BLACKEVIN_ENDPOINT')

    saved.each_key { |name| ENV.delete(name) }
    example.run
  ensure
    %w[BLACKEVIN_KEY BLACKEVIN_REST_ENDPOINT BLACKEVIN_ENDPOINT].each { |name| ENV.delete(name) }
    saved.each { |name, value| ENV[name] = value }
  end

  it 'works unconfigured when BLACKEVIN_KEY is in the environment' do
    ENV['BLACKEVIN_KEY'] = 'secret.envkid'

    expect(described_class.rest.auth.create_token_request.key_name).to eq('envkid')
    expect(described_class.rest.rest_endpoint).to eq('https://api.blackevin.com')
  end

  it 'prefers a configured key over the environment' do
    ENV['BLACKEVIN_KEY'] = 'secret.envkid'

    described_class.configure { |config| config.key = 'secret.configured' }

    expect(described_class.rest.auth.create_token_request.key_name).to eq('configured')
  end

  it 'memoizes the client, and rebuilds it when reconfigured' do
    described_class.configure { |config| config.key = 'secret.one' }

    first = described_class.rest

    expect(described_class.rest).to be(first)

    described_class.configure { |config| config.rest_endpoint = 'http://localhost:3000' }

    expect(described_class.rest).not_to be(first)
    expect(described_class.rest.rest_endpoint).to eq('http://localhost:3000')
  end
end
