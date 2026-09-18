# frozen_string_literal: true

require 'json'

module Blackevin
  # The token endpoint a browser's +authUrl+ points at, as a Rack application —
  # so the same object mounts in Rails, Sinatra, Hanami or a bare +config.ru+.
  #
  # The block receives the Rack env and answers who is asking. Return the
  # arguments for {Rest::Auth#create_token_request}, or nil to refuse:
  #
  #   TOKENS = Blackevin::TokenEndpoint.new do |env|
  #     user = env["warden"]&.user
  #
  #     next unless user
  #
  #     {client_id: user.id, capability: {"team:#{user.team_id}" => %w[subscribe publish]}}
  #   end
  #
  #   # Rails:   mount TOKENS, at: "/blackevin/token"
  #   # Sinatra: map("/blackevin/token") { run TOKENS }
  #
  # This gem does not depend on Rack; a Rack app is only an object with +call+.
  class TokenEndpoint
    ALLOWED_METHODS = %w[GET POST].freeze

    HEADERS = {
      'content-type' => 'application/json',
      'cache-control' => 'no-store'
    }.freeze

    # @param rest [Blackevin::Rest, nil] defaults to {Blackevin.rest}, resolved per request
    # @yieldparam env [Hash] the Rack env
    # @yieldreturn [Hash, nil] keyword arguments for +create_token_request+, or nil to answer 401
    def initialize(rest: nil, &identify)
      raise ArgumentError, 'TokenEndpoint needs a block that identifies the caller' unless identify

      @rest = rest
      @identify = identify
    end

    # @param env [Hash] the Rack env
    # @return [Array(Integer, Hash, Array<String>)]
    def call(env)
      unless ALLOWED_METHODS.include?(env['REQUEST_METHOD'])
        return respond(405, {'error' => 'method not allowed'}, 'allow' => ALLOWED_METHODS.join(', '))
      end

      case @identify.call(env)
      in nil | false
        respond(401, {'error' => 'unauthorized'})
      in Hash => params
        respond(200, (@rest || Blackevin.rest).auth.create_token_request(**params.transform_keys(&:to_sym)).to_h)
      in other
        raise ConfigurationError, "the TokenEndpoint block must return a Hash or nil, got #{other.class}"
      end
    end

    private

    def respond(status, body, extra = {})
      [status, HEADERS.merge(extra), [JSON.generate(body)]]
    end
  end
end
