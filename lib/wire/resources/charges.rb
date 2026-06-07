# frozen_string_literal: true

require_relative "base"

module Wire
  module Resources
    # Charges: retrieve, list.
    class Charges < Base
      def retrieve(id)
        @client.request("GET", "/v1/charges/#{URI.encode_www_form_component(id.to_s)}")
      end

      # Returns an Enumerator that auto-paginates across all pages.
      def list(params = {})
        paginate("/v1/charges", params)
      end
    end
  end
end
