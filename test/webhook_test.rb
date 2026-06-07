# frozen_string_literal: true

require_relative "test_helper"

class WebhookTest < Minitest::Test
  VECTORS = JSON.parse(
    File.read(File.expand_path("data/webhook-signatures.json", __dir__))
  )

  # Conformance: every shared test vector must pass identically across SDKs.
  VECTORS["cases"].each do |c|
    define_method("test_vector_#{c['name']}") do
      ok = true
      event = nil
      begin
        event = Wire::Webhook.verify_at(
          c["body"], c["header"], VECTORS["secret"],
          tolerance: VECTORS["tolerance_seconds"], now: VECTORS["now"]
        )
      rescue Wire::SignatureVerificationError
        ok = false
      end

      assert_equal c["valid"], ok, "vector #{c['name']} expected valid=#{c['valid']}"
      refute_nil event["type"] if c["valid"]
    end
  end

  def test_verify_uses_current_time
    secret = VECTORS["secret"]
    body = '{"id":"evt_1","object":"event","type":"payment_intent.succeeded"}'
    t = Time.now.to_i
    sig = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{t}.#{body}")
    header = "t=#{t},v1=#{sig}"

    event = Wire::Webhook.verify(body, header, secret)
    assert_equal "payment_intent.succeeded", event["type"]
  end

  def test_fails_closed_on_missing_v1
    assert_raises(Wire::SignatureVerificationError) do
      Wire::Webhook.verify_at("{}", "t=1700000100", "s", now: 1_700_000_100)
    end
  end

  def test_fails_closed_on_missing_t
    assert_raises(Wire::SignatureVerificationError) do
      Wire::Webhook.verify_at("{}", "v1=abcd", "s", now: 1_700_000_100)
    end
  end

  def test_secure_compare_rejects_length_mismatch
    refute Wire::Webhook.secure_compare("abc", "abcd")
  end

  def test_secure_compare_accepts_equal
    assert Wire::Webhook.secure_compare("deadbeef", "deadbeef")
  end
end
