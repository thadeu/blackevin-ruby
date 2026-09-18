# frozen_string_literal: true

require_relative "lib/blackevin/version"

Gem::Specification.new do |spec|
  spec.name = "blackevin"
  spec.version = Blackevin::VERSION
  spec.authors = ["Blackevin"]

  spec.summary = "Blackevin Ruby SDK"
  spec.description = "Sign token requests, publish, read history and presence, and manage queues on Blackevin. " \
    "Standard library only: no runtime dependencies. Ruby 3.0 and up. Works in Rails, Sinatra, Hanami or plain Ruby."
  spec.homepage = "https://blackevin.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "documentation_uri" => "https://docs.blackevin.com",
    "source_code_uri" => "https://github.com/thadeu/blackevin-ruby",
    "changelog_uri" => "https://github.com/thadeu/blackevin-ruby/blob/main/CHANGELOG.md"
  }

  spec.files = Dir.chdir(__dir__) do
    Dir["README.md", "CHANGELOG.md", "LICENSE", "blackevin.gemspec", "lib/**/*.rb"]
  end

  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rspec", ">= 3.13", "< 4.0"
  spec.add_development_dependency "standard", ">= 1.0"
  spec.add_development_dependency "railties", ">= 7.0"
end
