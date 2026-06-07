# frozen_string_literal: true

require "json"
require "openssl"

require_relative "errors"

module Wire
  # Raised when a webhook signature does not verify (fail closed).
  class SignatureVerificationError < Error; end

  # Webhook verifies inbound webhook signatures.
  #
  # Header format: "WirePayment-Signature: t=<unix>,v1=<hex>" where
  #   hex = HMAC-SHA256(secret, "<t>.<rawBody>")
  #
  # Verification runs on the RAW request body, before any JSON parsing.
  module Webhook
    SIGNATURE_HEADER = "WirePayment-Signature"
    DEFAULT_TOLERANCE_SECONDS = 300

    module_function

    # Verify a webhook signature and return the parsed event (Hash).
    #
    # @param payload [String] raw, unparsed request body.
    # @param header [String] value of the WirePayment-Signature header.
    # @param secret [String] endpoint signing secret (whsec_...).
    # @param tolerance [Integer] max allowed clock skew in seconds.
    # @raise [SignatureVerificationError] on any parse failure, timestamp
    #   outside tolerance, or signature mismatch.
    def verify(payload, header, secret, tolerance: DEFAULT_TOLERANCE_SECONDS)
      verify_at(payload, header, secret, tolerance: tolerance, now: Time.now.to_i)
    end

    # verify_at is the testable core taking an explicit `now` (unix seconds).
    def verify_at(payload, header, secret, tolerance: DEFAULT_TOLERANCE_SECONDS, now:)
      t, v1 = parse_header(header)
      raise SignatureVerificationError, "malformed signature header" if t.nil? || v1.nil? || v1.empty?

      if (now - t).abs > tolerance
        raise SignatureVerificationError, "timestamp outside tolerance"
      end

      body = payload.to_s
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{t}.#{body}")

      unless secure_compare(expected, v1)
        raise SignatureVerificationError, "signature mismatch"
      end

      JSON.parse(body)
    end

    # parse_header extracts t (Integer) and v1 (hex String) from the header.
    # Returns [nil, nil] when t is missing or not an integer.
    def parse_header(header)
      t = nil
      v1 = nil
      header.to_s.split(",").each do |part|
        k, v = part.strip.split("=", 2)
        case k
        when "t"
          parsed = Integer(v, exception: false)
          return [nil, nil] if parsed.nil?

          t = parsed
        when "v1"
          v1 = v
        end
      end
      [t, v1]
    end

    # Constant-time comparison. Prefers OpenSSL's fixed-length compare,
    # falling back to a Rack-style XOR comparison on older rubies.
    def secure_compare(a, b)
      a = a.to_s
      b = b.to_s
      if OpenSSL.respond_to?(:fixed_length_secure_compare)
        return false unless a.bytesize == b.bytesize

        OpenSSL.fixed_length_secure_compare(a, b)
      else
        return false unless a.bytesize == b.bytesize

        l = a.unpack("C*")
        res = 0
        b.each_byte { |byte| res |= byte ^ l.shift }
        res.zero?
      end
    end
  end
end
