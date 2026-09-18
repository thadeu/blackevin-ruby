# frozen_string_literal: true

require "json"

module Blackevin
  # What the server said when it refused.
  #
  # Branch on {#status_code} and {#reason}, never on the message: the message
  # is the server's sentence, written for a person.
  class Error < StandardError
    QUOTA_STATUS = 429

    # @return [Integer, nil] the HTTP status, or nil when no response arrived
    attr_reader :status_code

    # @return [String, nil] a stable slug such as "queue_limit", when the server sent one
    attr_reader :reason

    def initialize(message, status_code = nil, reason = nil)
      super(message)

      @status_code = status_code
      @reason = reason
    end

    # True when this is a plan ceiling rather than a bug or a bad credential.
    def quota? = status_code == QUOTA_STATUS

    # Lets a rescue branch by shape instead of by a chain of conditionals:
    #
    #   case error
    #   in {reason: "queue_limit"} then upgrade_prompt
    #   in {status_code: 401 | 403} then rotate_key
    #   in {status_code: nil} then retry_later
    #   end
    def deconstruct_keys(_keys) = {status_code: status_code, reason: reason, message: message}

    # Builds the error for a non-2xx response, keeping the server's sentence.
    #
    # A body that is not JSON degrades to the status alone: a proxy answering
    # HTML on a 502 must not replace a useful error with a parse failure.
    #
    # @param what [String] the operation label, e.g. "publish"
    # @param status [Integer]
    # @param body [String, nil] the raw response body
    # @return [Blackevin::Error]
    def self.from_response(what, status, body)
      parsed = parse(body)

      detail = case parsed
      in {error: String => sentence} unless sentence.empty? then sentence
      else status
      end

      reason = case parsed
      in {reason: String => slug} then slug
      else nil
      end

      new("#{what} failed: #{detail}", status, reason)
    end

    def self.parse(body)
      case JSON.parse(body.to_s, symbolize_names: true)
      in Hash => parsed then parsed
      else {}
      end
    rescue JSON::ParserError
      {}
    end

    private_class_method :parse
  end

  # The request never produced a response: DNS, refused connection, TLS, timeout.
  class ConnectionError < Error
    def initialize(message)
      super(message, nil, nil)
    end
  end

  # The SDK was given something it cannot work with, before any network call.
  class ConfigurationError < Error
    def initialize(message)
      super(message, nil, nil)
    end
  end
end
