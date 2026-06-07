# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  def test_sends_auth_and_decodes
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      { status: 200, json: { "id" => "pi_1", "object" => "payment_intent", "amount" => 50_000 } }
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    pi = client.payment_intents.retrieve("pi_1")

    assert_equal "Bearer sk_test_123", adapter.calls.last[:headers]["Authorization"]
    assert_equal "pi_1", pi["id"]
    assert_equal 50_000, pi["amount"]
  end

  def test_retries_on_503
    n = 0
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      n += 1
      if n < 3
        { status: 503, json: {} }
      else
        { status: 200, json: { "id" => "pi_1", "object" => "payment_intent" } }
      end
    end
    client = Wire::Client.new("sk_test_123", max_retries: 3, backoff: 0, http_adapter: adapter)

    client.payment_intents.retrieve("pi_1")

    assert_equal 3, n
  end

  def test_retries_on_429
    n = 0
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      n += 1
      if n < 2
        { status: 429, json: {} }
      else
        { status: 200, json: { "id" => "pi_1", "object" => "payment_intent" } }
      end
    end
    client = Wire::Client.new("sk_test_123", max_retries: 3, backoff: 0, http_adapter: adapter)

    client.payment_intents.retrieve("pi_1")

    assert_equal 2, n
  end

  def test_does_not_retry_on_400
    n = 0
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      n += 1
      { status: 400, json: { "error" => { "type" => "invalid_request_error", "message" => "bad" } } }
    end
    client = Wire::Client.new("sk_test_123", max_retries: 3, backoff: 0, http_adapter: adapter)

    assert_raises(Wire::WireError) { client.payment_intents.retrieve("x") }
    assert_equal 1, n
  end

  def test_retries_on_network_error_then_raises
    n = 0
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      n += 1
      { raise: Wire::ConnectionError.new("boom") }
    end
    client = Wire::Client.new("sk_test_123", max_retries: 2, backoff: 0, http_adapter: adapter)

    assert_raises(Wire::ConnectionError) { client.payment_intents.retrieve("x") }
    assert_equal 3, n # initial + 2 retries
  end

  def test_sends_idempotency_key_on_post
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      { status: 200, json: { "id" => "pi_1", "object" => "payment_intent" } }
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    client.payment_intents.create(amount: 1)

    key = adapter.calls.last[:headers]["Idempotency-Key"]
    refute_nil key
    refute_empty key
  end

  def test_reuses_idempotency_key_across_retries
    keys = []
    n = 0
    adapter = StubAdapter.new do |_m, _u, h, _b|
      keys << h["Idempotency-Key"]
      n += 1
      if n < 3
        { status: 500, json: {} }
      else
        { status: 200, json: { "id" => "pi_1", "object" => "payment_intent" } }
      end
    end
    client = Wire::Client.new("sk_test_123", max_retries: 3, backoff: 0, http_adapter: adapter)

    client.payment_intents.create(amount: 1)

    assert_equal 3, keys.length
    assert_equal 1, keys.uniq.length, "idempotency key must be reused across retries"
  end

  def test_caller_supplied_idempotency_key_is_used
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      { status: 200, json: { "id" => "pi_1", "object" => "payment_intent" } }
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    client.payment_intents.create(amount: 1, idempotency_key: "idk_custom")

    assert_equal "idk_custom", adapter.calls.last[:headers]["Idempotency-Key"]
  end

  def test_honors_retry_after_header
    n = 0
    slept = []
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      n += 1
      if n < 2
        { status: 429, headers: { "retry-after" => "1" }, json: {} }
      else
        { status: 200, json: { "id" => "pi_1", "object" => "payment_intent" } }
      end
    end
    client = Wire::Client.new("sk_test_123", max_retries: 3, backoff: 0, http_adapter: adapter)
    # Stub sleep to capture the requested delay without actually waiting.
    client.define_singleton_method(:sleep_for) { |s| slept << s }

    client.payment_intents.retrieve("x")

    assert_includes slept, 1.0
  end

  def test_does_not_expose_api_key_in_errors
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      { status: 500, body: "internal error" }
    end
    client = Wire::Client.new("sk_live_supersecret", backoff: 0, http_adapter: adapter)

    err = assert_raises(Wire::WireError) { client.payment_intents.retrieve("x") }
    refute_includes err.to_s, "sk_live_supersecret"
  end

  def test_requires_api_key
    assert_raises(ArgumentError) { Wire::Client.new("") }
    assert_raises(ArgumentError) { Wire::Client.new(nil) }
  end
end
