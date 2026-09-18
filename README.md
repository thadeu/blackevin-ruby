# blackevin

The server-side Ruby SDK for [Blackevin](https://blackevin.com) realtime.

Sign token requests for your browsers, publish from a job or a webhook, read
history and presence, manage queues.

**No runtime dependencies.** `net/http`, `openssl` and `json` from the standard
library — nothing that can break under you in an upgrade. Ruby 3.0 and up, in
Rails, Sinatra, Hanami or a plain script.

```ruby
gem "blackevin"
```

## Configure

With `BLACKEVIN_KEY` in the environment there is nothing to configure:

```ruby
Blackevin.rest.channels.get("room:42").publish("greeting", {text: "hi"})
```

Or say it explicitly, once, at boot:

```ruby
Blackevin.configure do |config|
  config.key = ENV.fetch("BLACKEVIN_KEY")   # secret.keyId, from the console
  config.open_timeout = 5                   # seconds
  config.read_timeout = 10
end
```

`Blackevin.rest` is one shared, thread-safe client. For more than one key, build
your own: `Blackevin::Rest.new(key: …)`.

Against a local or self-hosted node, which serves REST and the socket from one
origin, set `BLACKEVIN_ENDPOINT=ws://localhost:3000` (or `config.endpoint`) and the
REST base is derived from it.

## Token endpoint — the part every app needs

Your API key is your account, so it never goes to a browser. The browser asks
**your** server for a TokenRequest: signed with the key, scoped to what this
user may touch, dead after its `ttl`. Signing is local — no call to Blackevin, so
your sign-in never depends on us being reachable.

The browser side is the JavaScript SDK with `authUrl: "/blackevin/token"`.

### Rails

```ruby
# app/controllers/blackevin_tokens_controller.rb
class BlackevinTokensController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: Blackevin.rest.auth.create_token_request(
      client_id: current_user.id,
      ttl: 1.hour.in_milliseconds,
      capability: {
        "team:#{current_user.team_id}" => %w[subscribe publish],
        "presence:team:#{current_user.team_id}" => %w[presence]
      }
    )
  end
end

# config/routes.rb
resource :blackevin_token, only: :show, path: "blackevin/token"
```

The key can live in credentials instead of the environment — the Railtie reads
`credentials.blackevin.key`, and `config.blackevin.*` in an environment file:

```ruby
# config/environments/development.rb
config.blackevin.endpoint = "ws://localhost:3000"
```

### Sinatra

```ruby
require "sinatra"
require "blackevin"

get "/blackevin/token" do
  halt 401 unless current_user

  content_type :json
  Blackevin.rest.auth.create_token_request(client_id: current_user.id).to_json
end
```

### Anything Rack (Hanami, Roda, `config.ru`)

`Blackevin::TokenEndpoint` is a Rack application. The block receives the Rack env
and answers who is asking; `nil` is a 401.

```ruby
TOKENS = Blackevin::TokenEndpoint.new do |env|
  user = env["warden"]&.user

  next unless user

  {client_id: user.id, capability: {"team:#{user.team_id}" => %w[subscribe publish]}}
end

# Hanami:  mount TOKENS, at: "/blackevin/token"
# Rails:   mount TOKENS, at: "/blackevin/token"
# Rack:    map("/blackevin/token") { run TOKENS }
```

## Publish

```ruby
channel = Blackevin.rest.channels.get("orders:#{order.id}")

channel.publish("status", {state: "shipped"})
```

It goes through the same fanout a socket publish does: subscribers, account
queues and integrations all see it. One HTTP request per publish — from a Rails
request, prefer a job:

```ruby
class BlackevinPublishJob < ApplicationJob
  retry_on Blackevin::ConnectionError, wait: :polynomially_longer

  def perform(channel, event, data)
    Blackevin.rest.channels.get(channel).publish(event, data)
  end
end
```

## History and presence

```ruby
channel.history(limit: 50)        # => [Blackevin::Message], newest first
channel.presence.get              # => [Blackevin::PresenceMember]
channel.presence.history          # => [Blackevin::PresenceEvent]

message = channel.history.first
message.name        # "status"
message.data        # {"state" => "shipped"}
message.time        # a Time; message.timestamp is the wire value, in ms
```

## Sign a user out everywhere

```ruby
Blackevin.rest.clients.disconnect(user.id)   # => how many connections were closed
```

## Queues

The key needs the `amqp-subscribe` capability. A queue is addressed by its `id`.

```ruby
queues = Blackevin.rest.queues

queue = queues.upsert(name: "inbox", max_length: 10_000)
queues.add_rule(queue.id, source_pattern: "orders:*")

queues.update(queue.id, enabled: false)   # pause
queues.list(all: true)                    # paused ones included
queues.delete(queue.id)
```

## Errors

One rescue covers everything the SDK raises:

```ruby
begin
  channel.publish("status", payload)
rescue Blackevin::Error => error
  error.status_code   # 403, 429, … or nil when no response arrived
  error.reason        # "queue_limit", "connection_limit", or nil
  error.quota?        # a plan ceiling — show an upgrade prompt, retry later
  error.message       # the server's own sentence; do not branch on it
end
```

Errors, token requests and every returned value support pattern matching, so a
rescue can branch by shape:

```ruby
rescue Blackevin::Error => error
  case error
  in {reason: "queue_limit"} then redirect_to upgrade_path
  in {status_code: 401 | 403} then raise
  in {status_code: nil} then retry_job wait: 30.seconds
  end
```

- `Blackevin::ConnectionError` — DNS, refused, TLS, timeout. Worth retrying.
- `Blackevin::ConfigurationError` — a missing or malformed key, raised before any request.

## Acting as one client

A token instead of a key restricts the client to that token's capability:

```ruby
details = Blackevin.rest.auth.request_token(
  Blackevin.rest.auth.create_token_request(client_id: "worker-1", capability: {"jobs:*" => %w[publish]})
)

Blackevin::Rest.new(token: details.token).channels.get("jobs:1").publish("done")
```

## Testing your app

Swap the transport and nothing leaves the process:

```ruby
Blackevin.configure do |config|
  config.key = "secret.test"
  config.transport = ->(request) { Blackevin::Response.new(status: 200, body: "{}") }
end
```

## Development

```sh
bundle install
bundle exec rake            # rspec + rubocop (Standard rules, single quotes)
bundle exec rake contract:sync   # refresh spec/contract from ../blackevin/spec
```

### Releasing

Bump `lib/blackevin/version.rb`, add the entry to `CHANGELOG.md`, commit, then:

```sh
bundle exec rake tag   # tags vX.Y.Z from version.rb and pushes it
```

The tag runs `.github/workflows/release.yml`: lint, tests, publish to RubyGems by
Trusted Publishing (no API key), and a GitHub release with the `.gem` attached.

`spec/contract` is a copy of the language-neutral contract — an OpenAPI file and
JSON fixtures — that every Blackevin SDK is tested against. The suite fails when
the contract gains an operation this gem does not implement.

## License

MIT.
