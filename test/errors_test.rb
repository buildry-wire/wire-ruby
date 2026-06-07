# frozen_string_literal: true

require_relative "test_helper"

class ErrorsTest < Minitest::Test
  def test_parses_the_envelope
    body = JSON.generate(
      "error" => {
        "type" => "invalid_request_error",
        "code" => "amount_invalid",
        "message" => "amount must be positive",
        "param" => "amount",
        "request_id" => "req_123",
        "doc_url" => "https://docs.wire.mn/errors/amount_invalid",
        "operator_decline_code" => "insufficient_funds"
      }
    )

    err = Wire.parse_error(400, body)

    assert_instance_of Wire::WireError, err
    assert_equal 400, err.status_code
    assert_equal "invalid_request_error", err.type
    assert_equal "amount_invalid", err.code
    assert_equal "amount", err.param
    assert_equal "req_123", err.request_id
    assert_equal "https://docs.wire.mn/errors/amount_invalid", err.doc_url
    assert_equal "insufficient_funds", err.operator_decline_code
    assert_includes err.to_s, "amount must be positive"
    assert_includes err.to_s, "req_123"
  end

  def test_falls_back_on_non_json
    err = Wire.parse_error(500, "not json")
    assert_instance_of Wire::WireError, err
    assert_equal 500, err.status_code
    assert_equal "api_error", err.type
  end

  def test_falls_back_on_json_without_error_key
    err = Wire.parse_error(502, JSON.generate("message" => "gateway"))
    assert_instance_of Wire::WireError, err
    assert_equal 502, err.status_code
  end

  def test_error_class_hierarchy
    assert Wire::WireError.ancestors.include?(Wire::Error)
    assert Wire::ConnectionError.ancestors.include?(Wire::Error)
    assert Wire::TimeoutError.ancestors.include?(Wire::ConnectionError)
  end
end
