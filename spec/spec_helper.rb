# frozen_string_literal: true

# Before the library, or its files are loaded unmeasured. Opt-in, so running one
# spec file does not fail the coverage floor.
if ENV['COVERAGE']
  require 'simplecov'

  SimpleCov.start
end

require 'blackevin'

Dir[File.join(__dir__, 'support', '*.rb')].each { |file| require file }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.order = :random

  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }

  config.include ContractFixtures

  config.before { Blackevin.reset! }

  # Rest.new falls back to the environment, so a developer's own BLACKEVIN_KEY
  # must not leak into an example that expects no key at all.
  config.around do |example|
    names = %w[BLACKEVIN_KEY BLACKEVIN_REST_ENDPOINT BLACKEVIN_ENDPOINT]
    saved = ENV.to_h.slice(*names)

    names.each { |name| ENV.delete(name) }
    example.run
  ensure
    names.each { |name| ENV.delete(name) }
    saved.each { |name, value| ENV[name] = value }
  end
end
