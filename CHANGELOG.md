# Changelog

## 0.1.0

- Remove lint from CI

## 0.1.0

First release. Server-side REST client, standard library only.

- `Blackevin::Rest` — `auth.create_token_request` (local HMAC signing), `auth.request_token`,
  `channels.get(name).publish / history`, `presence.get / history`, `clients.disconnect`,
  and `queues` (list, upsert, update, delete, rules, add_rule, delete_rule).
- `Blackevin.configure` and `Blackevin.rest` for a process-wide client; reads `BLACKEVIN_KEY`,
  `BLACKEVIN_REST_ENDPOINT` and `BLACKEVIN_ENDPOINT`.
- `Blackevin::TokenEndpoint`, a Rack application for the browser's `authUrl`, mountable in Rails,
  Sinatra and Hanami.
- An optional Railtie: `config.blackevin.*` and `credentials.blackevin.key`.
- `Blackevin::Error` (`status_code`, `reason`, `quota?`), `Blackevin::ConnectionError`,
  `Blackevin::ConfigurationError`.
- Pattern matching (`deconstruct_keys`) on errors, token requests, token details and every returned value.
- Ruby 3.0 and up. The suite runs on 3.0 through 3.4.
- Tested against the language-neutral contract in `spec/contract`.
