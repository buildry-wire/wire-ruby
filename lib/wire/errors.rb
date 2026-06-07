# frozen_string_literal: true

require "json"

module Wire
  # Base class for every error raised by this library.
  class Error < StandardError; end

  # WireError is a typed error decoded from the API error envelope
  # ({ "error": { ... } }). It is raised for any non-2xx API response.
  class WireError < Error
    attr_reader :type, :code, :param, :request_id, :doc_url,
                :operator_decline_code, :status_code

    def initialize(message, type: "api_error", code: nil, param: nil,
                   request_id: nil, doc_url: nil, operator_decline_code: nil,
                   status_code: nil)
      super(message)
      @type = type
      @code = code
      @param = param
      @request_id = request_id
      @doc_url = doc_url
      @operator_decline_code = operator_decline_code
      @status_code = status_code
    end

    def to_s
      "#{super} (type=#{type}, code=#{code}, status=#{status_code}, " \
        "request_id=#{request_id})"
    end
  end

  # Raised for connection failures and request timeouts. Distinct from
  # WireError so callers can treat transport problems separately.
  class ConnectionError < Error; end

  # Raised when a request exceeds the configured timeout.
  class TimeoutError < ConnectionError; end

  # Decode the Wire error envelope; fall back to a generic error.
  #
  # The api_key is never read from or echoed into the error.
  def self.parse_error(status, body)
    begin
      env = JSON.parse(body)
      err = env.is_a?(Hash) ? env["error"] : nil
      if err.is_a?(Hash)
        return WireError.new(
          err["message"] || "request failed",
          type: err["type"] || "api_error",
          code: err["code"],
          param: err["param"],
          request_id: err["request_id"],
          doc_url: err["doc_url"],
          operator_decline_code: err["operator_decline_code"],
          status_code: status
        )
      end
    rescue JSON::ParserError
      # fall through to generic error
    end

    WireError.new(
      "unexpected response (status #{status})",
      type: "api_error",
      status_code: status
    )
  end
end
