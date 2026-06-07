# frozen_string_literal: true

require_relative "test_helper"

class ResourcesTest < Minitest::Test
  def test_creates_a_payment_intent
    adapter = StubAdapter.new do |m, _u, _h, _b|
      assert_equal "POST", m
      { status: 200, json: { "id" => "pi_1", "object" => "payment_intent", "amount" => 50_000, "status" => "requires_payment_method" } }
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    pi = client.payment_intents.create(amount: 50_000, currency: "MNT", allowed_operators: ["sandbox"])

    assert_equal "/v1/payment_intents", adapter.calls.last[:path]
    assert_equal "pi_1", pi["id"]
    assert_equal "requires_payment_method", pi["status"]
    body = JSON.parse(adapter.calls.last[:body])
    assert_equal ["sandbox"], body["allowed_operators"]
    refute body.key?("idempotency_key"), "idempotency_key must not leak into body"
  end

  def test_confirm_and_cancel_paths
    paths = []
    adapter = StubAdapter.new do |_m, u, _h, _b|
      paths << u
      { status: 200, json: { "id" => "pi_1", "object" => "payment_intent" } }
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    client.payment_intents.confirm("pi_1", return_url: "https://x.test/r")
    client.payment_intents.cancel("pi_1")

    assert_equal "/v1/payment_intents/pi_1/confirm", paths[0]
    assert_equal "/v1/payment_intents/pi_1/cancel", paths[1]
  end

  def test_auto_paginates_list
    adapter = StubAdapter.new do |_m, u, _h, _b|
      if u.include?("starting_after")
        { status: 200, json: { "object" => "list", "has_more" => false, "data" => [{ "id" => "ch_2", "object" => "charge" }] } }
      else
        { status: 200, json: { "object" => "list", "has_more" => true, "data" => [{ "id" => "ch_1", "object" => "charge" }] } }
      end
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    ids = client.charges.list(limit: 1).map { |ch| ch["id"] }

    assert_equal %w[ch_1 ch_2], ids
  end

  def test_list_is_lazy_enumerator
    adapter = StubAdapter.new do |_m, _u, _h, _b|
      { status: 200, json: { "object" => "list", "has_more" => true, "data" => [{ "id" => "ch_x", "object" => "charge" }] } }
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    enum = client.events.list
    assert_kind_of Enumerator, enum
    # Take only one item from an infinite has_more stream; proves laziness.
    first = enum.first
    assert_equal "ch_x", first["id"]
  end

  def test_retrieve_charge
    adapter = StubAdapter.new do |_m, u, _h, _b|
      assert_equal "/v1/charges/ch_1", u
      { status: 200, json: { "id" => "ch_1", "object" => "charge" } }
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    assert_equal "ch_1", client.charges.retrieve("ch_1")["id"]
  end

  def test_webhook_endpoint_crud
    adapter = StubAdapter.new do |m, u, _h, _b|
      case [m, u]
      when ["DELETE", "/v1/webhook_endpoints/we_1"]
        { status: 200, json: { "id" => "we_1", "object" => "webhook_endpoint", "deleted" => true } }
      else
        { status: 200, json: { "id" => "we_1", "object" => "webhook_endpoint", "url" => "https://x.test/wh" } }
      end
    end
    client = Wire::Client.new("sk_test_123", backoff: 0, http_adapter: adapter)

    created = client.webhook_endpoints.create(url: "https://x.test/wh", enabled_events: ["payment_intent.succeeded"])
    assert_equal "we_1", created["id"]

    updated = client.webhook_endpoints.update("we_1", status: "disabled")
    assert_equal "we_1", updated["id"]

    deleted = client.webhook_endpoints.delete("we_1")
    assert_equal true, deleted["deleted"]
  end
end
