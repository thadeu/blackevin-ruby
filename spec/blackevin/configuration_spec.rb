# frozen_string_literal: true

RSpec.describe Blackevin do
  it 'has no process-wide client' do
    expect(described_class).not_to respond_to(:rest)
  end

  describe 'Blackevin::Rest.new with no arguments' do
    it 'works unconfigured when BLACKEVIN_KEY is in the environment' do
      ENV['BLACKEVIN_KEY'] = 'secret.envkid'

      bk = Blackevin::Rest.new

      expect(bk.auth.create_token_request.key_name).to eq('envkid')
      expect(bk.rest_endpoint).to eq('https://api.blackevin.com')
    end

    it 'prefers the configured key over the environment' do
      ENV['BLACKEVIN_KEY'] = 'secret.envkid'

      described_class.configure { |config| config.key = 'secret.configured' }

      expect(Blackevin::Rest.new.api_key.key_name).to eq('configured')
    end

    it 'prefers an argument over the configuration' do
      described_class.configure do |config|
        config.key = 'secret.configured'
        config.rest_endpoint = 'http://configured:3000'
      end

      bk = Blackevin::Rest.new(key: 'secret.explicit', rest_endpoint: 'http://explicit:3000')

      expect(bk.api_key.key_name).to eq('explicit')
      expect(bk.rest_endpoint).to eq('http://explicit:3000')
    end

    it 'derives the REST base from a configured socket endpoint' do
      described_class.configure { |config| config.endpoint = 'ws://localhost:3000' }

      expect(Blackevin::Rest.new.rest_endpoint).to eq('http://localhost:3000')
    end

    it 'uses a configured transport, which is how an app silences the network in tests' do
      transport = RecordingTransport.new

      described_class.configure do |config|
        config.key = 'secret.kid'
        config.transport = transport
      end

      Blackevin::Rest.new.channels.get('room').publish('event')

      expect(transport.requests.size).to eq(1)
    end

    it 'passes configured timeouts to the default transport' do
      described_class.configure do |config|
        config.open_timeout = 1
        config.read_timeout = 2
      end

      allow(Blackevin::Transport).to receive(:new).and_call_original

      Blackevin::Rest.new

      expect(Blackevin::Transport).to have_received(:new).with(open_timeout: 1, read_timeout: 2)
    end

    it 'says every place a key can come from when there is none' do
      expect { Blackevin::Rest.new.auth.create_token_request }
        .to raise_error(Blackevin::ConfigurationError, /key:.*Blackevin\.configure.*BLACKEVIN_KEY/)
    end
  end

  it 'leaves a client already built alone when reconfigured' do
    described_class.configure { |config| config.key = 'secret.one' }

    bk = Blackevin::Rest.new

    described_class.configure { |config| config.key = 'secret.two' }

    expect(bk.api_key.key_name).to eq('one')
    expect(Blackevin::Rest.new.api_key.key_name).to eq('two')
  end
end
