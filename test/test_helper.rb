# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "json"
require "wirepayment"

# StubAdapter is an injectable HTTP transport for tests. It records the last
# request and returns canned responses from a handler block. Optionally raises
# transport errors to exercise retry logic.
class StubAdapter
  attr_reader :calls

  # @param handler a callable (method, path, headers, body) -> Hash with keys
  #   :status, :headers, :json (or :body). `path` is the request URI path with
  #   query string. It may also return :raise with an exception instance to
  #   simulate a network failure.
  def initialize(&handler)
    @handler = handler
    @calls = []
  end

  def call(method, uri, headers, body, _timeout)
    path = uri.request_uri
    @calls << { method: method, path: path, headers: headers, body: body }
    result = @handler.call(method, path, headers, body)
    raise result[:raise] if result[:raise]

    body_str = if result.key?(:body)
                 result[:body]
               else
                 JSON.generate(result[:json] || {})
               end
    Wire::Response.new(
      status: result[:status] || 200,
      headers: result[:headers] || {},
      body: body_str
    )
  end
end
