# frozen_string_literal: true

module Blackevin
  # Which hosts the SDK talks to: explicit option, then environment, then the
  # production default.
  #
  # The REST base is derived from the socket endpoint only when that endpoint
  # was given, because a dev or self-hosted node serves both from one origin.
  # Production serves them from two names, so the default never derives.
  module Endpoints
    DEFAULT_WS = 'wss://ws.blackevin.com'
    DEFAULT_REST = 'https://api.blackevin.com'

    ENV_WS = 'BLACKEVIN_ENDPOINT'
    ENV_REST = 'BLACKEVIN_REST_ENDPOINT'

    Resolved = Struct.new(:endpoint, :rest_endpoint, keyword_init: true)

    module_function

    # @param endpoint [String, nil] socket endpoint, e.g. "ws://localhost:3000"
    # @param rest_endpoint [String, nil] REST base URL
    # @param env [#[]] injected for tests; defaults to ENV
    # @return [Resolved]
    def resolve(endpoint: nil, rest_endpoint: nil, env: ENV)
      explicit_ws = present(endpoint) || present(env[ENV_WS])

      rest = present(rest_endpoint) ||
             present(env[ENV_REST]) ||
             (explicit_ws ? derive_rest(explicit_ws) : DEFAULT_REST)

      Resolved.new(endpoint: explicit_ws || DEFAULT_WS, rest_endpoint: rest)
    end

    def derive_rest(ws_endpoint) = ws_endpoint.sub(/\Aws/i, 'http').delete_suffix('/')

    def present(value) = value.to_s.strip.then { _1.empty? ? nil : _1 }
  end
end
