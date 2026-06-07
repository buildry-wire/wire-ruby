# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"

require_relative "errors"
require_relative "resources/payment_intents"
require_relative "resources/charges"
require_relative "resources/events"
require_relative "resources/webhook_endpoints"

module Wire
  DEFAULT_BASE_URL = "https://api.wire.mn"

  # Client is the Wire API client. Construct it with an API key (sk_live_...).
  #
  #   client = Wire::Client.new("sk_live_...")
  #   pi = client.payment_intents.create(amount: 50_000, currency: "MNT")
  class Client
    attr_reader :payment_intents, :charges, :events, :webhook_endpoints

    # @param api_key [String] secret API key (sk_live_...).
    # @param base_url [String] API base URL.
    # @param timeout [Numeric] per-request timeout in seconds.
    # @param max_retries [Integer] retry attempts for 429/5xx/network errors.
    # @param backoff [Numeric] base backoff in seconds (exponential w/ jitter).
    # @param http_adapter an optional object responding to
    #   #call(method, uri, headers, body, timeout) -> Wire::Response. Used to
    #   inject a stub transport in tests; defaults to Net::HTTP.
    def initialize(api_key, base_url: DEFAULT_BASE_URL, timeout: 30,
                   max_retries: 2, backoff: 0.5, http_adapter: nil)
      raise ArgumentError, "api_key is required" if api_key.nil? || api_key.empty?

      @api_key = api_key
      @base_url = base_url.sub(%r{/+\z}, "")
      @timeout = timeout
      @max_retries = max_retries
      @backoff = backoff
      @http_adapter = http_adapter || NetHTTPAdapter.new

      @payment_intents = Resources::PaymentIntents.new(self)
      @charges = Resources::Charges.new(self)
      @events = Resources::Events.new(self)
      @webhook_endpoints = Resources::WebhookEndpoints.new(self)
    end

    # request performs an HTTP request with auth, idempotency, retries, and
    # error decoding, returning the parsed JSON body as a Hash.
    #
    # @param method [String] HTTP method ("GET", "POST", "DELETE").
    # @param path [String] request path (e.g. "/v1/payment_intents").
    # @param body [Hash, nil] request body, JSON-encoded when present.
    # @param query [Hash, nil] query parameters.
    # @param idempotency_key [String, nil] reused across retries; a random key
    #   is generated for POST when absent.
    def request(method, path, body: nil, query: nil, idempotency_key: nil)
      uri = build_uri(path, query)

      headers = {
        "Authorization" => "Bearer #{@api_key}",
        "Accept" => "application/json"
      }
      body_str = nil
      unless body.nil?
        body_str = JSON.generate(body)
        headers["Content-Type"] = "application/json"
      end
      if method == "POST"
        headers["Idempotency-Key"] = idempotency_key || self.class.new_idempotency_key
      end

      attempt = 0
      loop do
        begin
          resp = @http_adapter.call(method, uri, headers, body_str, @timeout)
        rescue TimeoutError, ConnectionError => e
          if attempt < @max_retries
            sleep_for(backoff_delay(attempt))
            attempt += 1
            next
          end
          raise e
        end

        if (resp.status == 429 || resp.status >= 500) && attempt < @max_retries
          delay = retry_after(resp.headers) || backoff_delay(attempt)
          sleep_for(delay)
          attempt += 1
          next
        end

        return handle_response(resp)
      end
    end

    def self.new_idempotency_key
      "idk_#{SecureRandom.hex(16)}"
    end

    private

    def build_uri(path, query)
      uri = URI.parse(@base_url + path)
      if query && !query.empty?
        pairs = query.reject { |_k, v| v.nil? || v == "" || v == 0 }
        uri.query = URI.encode_www_form(pairs) unless pairs.empty?
      end
      uri
    end

    def handle_response(resp)
      body = resp.body.to_s
      if resp.status >= 200 && resp.status < 300
        return body.empty? ? {} : JSON.parse(body)
      end
      raise Wire.parse_error(resp.status, body)
    end

    # Exponential backoff with full jitter.
    def backoff_delay(attempt)
      base = @backoff * (2**attempt)
      rand * base
    end

    def retry_after(headers)
      raw = headers["retry-after"] || headers["Retry-After"]
      return nil if raw.nil? || raw.to_s.empty?

      n = Integer(raw, exception: false)
      n&.positive? ? n.to_f : nil
    end

    def sleep_for(seconds)
      sleep(seconds) if seconds&.positive?
    end
  end

  # Response is the transport-agnostic result an http_adapter must return.
  Response = Struct.new(:status, :headers, :body, keyword_init: true)

  # NetHTTPAdapter is the default transport, built on stdlib Net::HTTP.
  class NetHTTPAdapter
    def call(method, uri, headers, body, timeout)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = timeout
      http.read_timeout = timeout
      http.write_timeout = timeout if http.respond_to?(:write_timeout=)

      req = build_request(method, uri, headers, body)

      begin
        res = http.request(req)
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
        raise Wire::TimeoutError, "request timed out: #{e.message}"
      rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => e
        raise Wire::ConnectionError, "request failed: #{e.message}"
      end

      Wire::Response.new(
        status: res.code.to_i,
        headers: normalize_headers(res),
        body: res.body
      )
    end

    private

    def build_request(method, uri, headers, body)
      klass = case method
              when "GET" then Net::HTTP::Get
              when "POST" then Net::HTTP::Post
              when "DELETE" then Net::HTTP::Delete
              when "PUT" then Net::HTTP::Put
              else raise ArgumentError, "unsupported method: #{method}"
              end
      req = klass.new(uri.request_uri)
      headers.each { |k, v| req[k] = v }
      req.body = body if body
      req
    end

    def normalize_headers(res)
      out = {}
      res.each_header { |k, v| out[k.downcase] = v }
      out
    end
  end
end
