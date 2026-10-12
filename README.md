# wirepayment

Official Ruby SDK for the [Wire](https://wire.mn) payment API — a unified
gateway over Mongolian payment operators. Server-side, Ruby 3.0+, built on the
standard library with no third-party runtime dependencies.

Full documentation: [docs.wire.mn](https://docs.wire.mn)

## Install

```ruby
# Gemfile
gem "wirepayment"
```

```bash
bundle install
# or
gem install wirepayment
```

```ruby
require "wirepayment"
```

## Quickstart

```ruby
client = Wire::Client.new("sk_live_...")

# Amounts are whole tögrög (MNT integer, no fractional part): 50000 = 50,000 ₮.
# Without allowed_operators, Wire routes to the operators enabled on your project.
pi = client.payment_intents.create(
  amount: 50_000,
  currency: "MNT"
)
puts pi["id"], pi["status"]

# Confirm it.
confirmed = client.payment_intents.confirm(pi["id"], return_url: "https://example.com/return")
puts confirmed["status"]
```

## Configuration

```ruby
client = Wire::Client.new(
  "sk_live_...",
  base_url: "https://api.wire.mn", # default
  timeout: 30,                     # seconds, default
  max_retries: 2,                  # default; retries 429/5xx/network with backoff
  backoff: 0.5                     # base seconds for exponential backoff w/ jitter
)
```

Every POST automatically sends an `Idempotency-Key` (generated if you don't
supply one), and the same key is reused across retries. Pass your own with
`idempotency_key:`.

## Auto-pagination

`list` returns a lazy `Enumerator` that follows `has_more` across pages:

```ruby
client.charges.list(limit: 50).each do |charge|
  puts charge["id"]
end

# Or collect everything:
events = client.events.list.to_a
```

## Webhook verification

Verify against the **raw** request body, before any JSON parsing:

```ruby
require "wirepayment"

# In a Rack/Rails controller:
payload = request.body.read
sig_header = request.headers[Wire::Webhook::SIGNATURE_HEADER] # "WirePayment-Signature"

begin
  event = Wire::Webhook.verify(payload, sig_header, ENV["WIRE_WEBHOOK_SECRET"])
  puts event["type"]
rescue Wire::SignatureVerificationError
  head :bad_request
end
```

## Error handling

```ruby
begin
  client.payment_intents.retrieve("pi_missing")
rescue Wire::WireError => e
  e.type                  # e.g. "invalid_request_error"
  e.code                  # e.g. "resource_missing"
  e.param
  e.request_id            # always preserved when present
  e.doc_url
  e.operator_decline_code
  e.status_code           # HTTP status
rescue Wire::ConnectionError => e
  # network failure or timeout (Wire::TimeoutError is a subclass)
end
```

The SDK never logs your API key and never includes it in error messages.

## License

MIT — see [LICENSE](LICENSE).
