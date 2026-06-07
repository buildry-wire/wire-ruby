# frozen_string_literal: true

require_relative "base"

module Wire
  module Resources
    # WebhookEndpoints: create, retrieve, update, delete, list.
    class WebhookEndpoints < Base
      # @param params [Hash] url:, enabled_events:. Pass idempotency_key: to override.
      def create(params = {})
        params = params.dup
        key = params.delete(:idempotency_key) || params.delete("idempotency_key")
        @client.request("POST", "/v1/webhook_endpoints", body: params, idempotency_key: key)
      end

      def retrieve(id)
        @client.request("GET", "/v1/webhook_endpoints/#{escape(id)}")
      end

      # @param params [Hash] url:, enabled_events:, status:.
      def update(id, params = {})
        params = params.dup
        key = params.delete(:idempotency_key) || params.delete("idempotency_key")
        @client.request(
          "POST", "/v1/webhook_endpoints/#{escape(id)}",
          body: params, idempotency_key: key
        )
      end

      def delete(id)
        @client.request("DELETE", "/v1/webhook_endpoints/#{escape(id)}")
      end

      # Returns an Enumerator that auto-paginates across all pages.
      def list(params = {})
        paginate("/v1/webhook_endpoints", params)
      end

      private

      def escape(id)
        URI.encode_www_form_component(id.to_s)
      end
    end
  end
end
