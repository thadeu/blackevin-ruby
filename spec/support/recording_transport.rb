# frozen_string_literal: true

require "json"

class RecordingTransport
  attr_reader :requests

  def initialize(status: 200, body: {})
    @status = status
    @body = body
    @requests = []
  end

  def call(request)
    @requests << request

    Blackevin::Response.new(status: @status, body: @body.is_a?(String) ? @body : JSON.generate(@body))
  end

  def last
    @requests.last
  end
end
