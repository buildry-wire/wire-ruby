# frozen_string_literal: true

require_relative "base"

module Wire
  module Resources
    # PaymentIntents: create, retrieve, confirm, cancel, list.
    class PaymentIntents < Base
      # @param params [Hash] amount:, currency:, automatic_operator:,
      #   allowed_operators:, metadata:. Pass idempotency_key: to override.
      def create(params = {})
        params = params.dup
        key = params.delete(:idempotency_key) || params.delete("idempotency_key")
        @client.request("POST", "/v1/payment_intents", body: params, idempotency_key: key)
      end

      def retrieve(id)
        @client.request("GET", "/v1/payment_intents/#{escape(id)}")
      end

      def confirm(id, params = {})
        params = params.dup
        key = params.delete(:idempotency_key) || params.delete("idempotency_key")
        @client.request(
          "POST", "/v1/payment_intents/#{escape(id)}/confirm",
          body: params, idempotency_key: key
        )
      end

      def cancel(id, idempotency_key: nil)
        @client.request(
          "POST", "/v1/payment_intents/#{escape(id)}/cancel",
          body: {}, idempotency_key: idempotency_key
        )
      end

      # Returns an Enumerator that auto-paginates across all pages.
      def list(params = {})
        paginate("/v1/payment_intents", params)
      end

      private

      def escape(id)
        URI.encode_www_form_component(id.to_s)
      end
    end
  end
end
