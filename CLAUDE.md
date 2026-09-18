# CLAUDE.md

The server-side Ruby SDK for Blackevin. Everything under `lib/` is public API that
ships into other people's applications.

## Rules

- **No runtime dependencies. None.** `net/http`, `openssl`, `json`, `securerandom`,
  `uri`. No Faraday, no `base64` (it left the default gems in Ruby 3.4 — use
  `pack("m0")`), no ActiveSupport. A development dependency is fine.
- **Framework-agnostic core.** Rails, Sinatra and Hanami are the users, in that
  order. Anything framework-specific is optional and loads only when the
  framework is present (`railtie.rb`). `TokenEndpoint` is plain Rack and must
  not require `rack`.
- **The contract decides.** `spec/contract` is copied from the monorepo's `spec/`
  (`rake contract:sync`). Never edit it here. If a fixture fails, the gem is
  wrong — or the contract changes upstream first.
- **Breaking a signature breaks someone's build.** Add, deprecate, then remove.
- **Never let a secret or a token reach `inspect`.**
- **Errors are the product.** Everything raised is a `Blackevin::Error`; the message
  keeps the server's sentence.

## Ruby version

The floor is **Ruby 3.0**, and the code is written for it: endless methods,
`case/in` pattern matching, numbered block parameters, `...` forwarding,
`Hash#except`. Public value objects implement `deconstruct_keys`.

Not available at 3.0, so not used: hash shorthand `{x:, y:}` and anonymous `&`
(3.1), `Data` (3.2), one-line `in` / rightward `=>` (experimental in 3.0, they
warn). Hash patterns match symbol keys only — parse with `symbolize_names: true`
before matching a JSON body. Every `case/in` on caller input needs an `else`
that raises a `Blackevin::ConfigurationError`, never a bare `NoMatchingPatternError`.

Check the floor for real before a release:

```sh
docker run --rm -v "$PWD":/src:ro ruby:3.0 bash -c \
  'cp -r /src /gem && cd /gem && rm -f Gemfile.lock && bundle install --quiet && bundle exec rspec'
```

## Style

Standard only (`bundle exec standardrb`). No `.rubocop.yml`, no `rubocop` command: RuboCop is in the bundle only because Standard is built on it. `.vscode/settings.json` points Ruby LSP at Standard, which otherwise picks RuboCop by itself. Blank lines between blocks of different
responsibility. Comments only as YARD documentation on public API, or where a
wire rule would otherwise look like a mistake.

## Commands

```sh
bundle exec rake          # rspec + standard
bundle exec rspec
bundle exec rake contract:sync
```

Update `CHANGELOG.md` whenever the version changes.
