# Changelog

## 0.2.0

**Breaking.** The client is an instance, always.

- Removed `Blackevin.rest`. There is no process-wide client and no class-level call that
  touches the network. Build one: `bk = Blackevin::Rest.new`.
- `Blackevin::Rest.new` now falls back, option by option, to `Blackevin.configure` and then to
  `BLACKEVIN_KEY` — so `new` with no arguments works wherever `Blackevin.rest` used to.
- Every part stands alone: `Blackevin::Rest::Auth.new`, `Channels.new`, `Channel.new(name)`,
  `Presence.new(name)`, `Clients.new` and `Queues.new` take an optional `client:` and build a
  `Blackevin::Rest` without one. `bk.auth`, `bk.channels` and the rest are those same classes.
- One class per file under `lib/blackevin/rest/`.
- `Blackevin.configure` only stores defaults. Reconfiguring no longer affects a client already built.
- `Blackevin::TokenEndpoint` without `rest:` builds a `Blackevin::Rest` per request.
- The Railtie is unchanged: it fills the configuration from `config.blackevin.*` and credentials.
- Style is RuboCop running Standard's rules with single quotes (`bundle exec rubocop`).
- `bundle exec rake coverage` runs the suite under SimpleCov, Rails subprocesses merged in, and
  fails under 100% lines or 95% branches.

Migrating: replace `Blackevin.rest` with `Blackevin::Rest.new`.

## 0.1.1

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
