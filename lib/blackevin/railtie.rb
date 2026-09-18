# frozen_string_literal: true

module Blackevin
  # Loaded only when Rails is. Lets the key live where a Rails app keeps secrets:
  #
  #   # config/credentials.yml.enc
  #   blackevin:
  #     key: ck_live_….kAbC
  #
  # and lets an environment file set the rest:
  #
  #   config.blackevin.rest_endpoint = "http://localhost:3000"
  #
  # An explicit +Blackevin.configure+ or +BLACKEVIN_KEY+ still wins over credentials.
  class Railtie < Rails::Railtie
    SETTINGS = %i[key rest_endpoint endpoint open_timeout read_timeout transport].freeze

    config.blackevin = ActiveSupport::OrderedOptions.new

    initializer "blackevin.configure" do |app|
      options = app.config.blackevin
      credentials_key = app.credentials.dig(:blackevin, :key) if app.respond_to?(:credentials)

      Blackevin.configure do |config|
        SETTINGS.each do |setting|
          value = options[setting]

          config.public_send(:"#{setting}=", value) unless value.nil?
        end

        config.key = credentials_key if config.key.nil? && credentials_key
      end
    end
  end
end
