# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-07

### Added
- Initial release of the `wirepayment` gem (`Wire` namespace).
- `Wire::Client` with Bearer auth, JSON encoding, configurable `base_url`,
  `timeout`, `max_retries`, and `backoff`.
- Automatic `Idempotency-Key` on POST requests, reused across retries.
- Exponential backoff with jitter on 429, 5xx, and network errors; honors
  `Retry-After`.
- Resources: payment intents (create, retrieve, confirm, cancel, list),
  charges (retrieve, list), events (retrieve, list), webhook endpoints
  (create, retrieve, update, delete, list).
- Cursor auto-pagination via lazy `Enumerator` following `has_more`.
- Typed `Wire::WireError` decoded from the API error envelope; distinct
  `Wire::ConnectionError` / `Wire::TimeoutError` for transport failures.
- `Wire::Webhook.verify` with HMAC-SHA256 signature verification, constant-time
  comparison, timestamp tolerance, and fail-closed behavior.

[1.0.0]: https://github.com/buildry-wire/wire-ruby/releases/tag/v1.0.0
