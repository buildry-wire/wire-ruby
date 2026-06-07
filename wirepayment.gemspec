# frozen_string_literal: true

require_relative "lib/wire/version"

Gem::Specification.new do |spec|
  spec.name = "wirepayment"
  spec.version = Wire::VERSION
  spec.authors = ["Buildry"]
  spec.summary = "Official Ruby SDK for the Wire payment API."
  spec.description =
    "Server-side Ruby client for the Wire unified payment gateway: payment " \
    "intents, charges, events, and webhook endpoints across Mongolian " \
    "payment operators, with automatic retries, idempotency, cursor " \
    "auto-pagination, and webhook signature verification."
  spec.homepage = "https://github.com/buildry-wire/wire-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "documentation_uri" => "https://docs.wire.mn",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb"] + ["README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]

  # Runtime uses only the Ruby standard library (net/http, json, openssl,
  # securerandom) — no third-party runtime dependencies.
end
