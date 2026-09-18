# frozen_string_literal: true

require 'json'

module ContractFixtures
  ROOT = File.expand_path('../contract', __dir__)

  def self.load(name)
    JSON.parse(File.read(File.join(ROOT, 'fixtures', "#{name}.json")))
  end

  def contract(name)
    ContractFixtures.load(name)
  end
end
