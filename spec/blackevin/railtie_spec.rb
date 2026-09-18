# frozen_string_literal: true

require "open3"
require "rbconfig"

# In a subprocess: booting Rails in this process would define Rails::Railtie for
# every other example, and the point of the gem is that it runs without it.
RSpec.describe "Blackevin::Railtie" do
  def boot(script)
    lib = File.expand_path("../../lib", __dir__)
    output, status = Open3.capture2e({"BLACKEVIN_KEY" => nil}, RbConfig.ruby, "-I", lib, "-e", script)

    raise output unless status.success?

    output.lines.last.to_s.strip
  end

  preamble = <<~RUBY
    require "rails"
    require "blackevin"

    class Dummy < Rails::Application
      config.eager_load = false
      config.logger = Logger.new(IO::NULL)
      config.secret_key_base = "x" * 64
  RUBY

  it "copies config.blackevin into the configuration" do
    script = <<~RUBY
      #{preamble}
        config.blackevin.key = "secret.fromrails"
        config.blackevin.rest_endpoint = "http://localhost:3000"
      end

      Dummy.initialize!

      puts [Blackevin.rest.api_key.key_name, Blackevin.rest.rest_endpoint].join(" ")
    RUBY

    expect(boot(script)).to eq("fromrails http://localhost:3000")
  end

  it "falls back to credentials when nothing else names a key" do
    script = <<~RUBY
      #{preamble}
        def credentials
          {blackevin: {key: "secret.fromcredentials"}}
        end
      end

      Dummy.initialize!

      puts Blackevin.rest.api_key.key_name
    RUBY

    expect(boot(script)).to eq("fromcredentials")
  end

  it "is not loaded without Rails" do
    expect(boot('require "blackevin"; puts defined?(Blackevin::Railtie).inspect')).to eq("nil")
  end
end
