# frozen_string_literal: true

require 'blackevin'

Dir[File.join(__dir__, 'support', '*.rb')].each { |file| require file }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.order = :random

  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }

  config.include ContractFixtures

  config.before { Blackevin.reset! }
end
