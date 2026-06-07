# frozen_string_literal: true

require_relative "base"

module Wire
  module Resources
    # Events: retrieve, list.
    class Events < Base
      def retrieve(id)
        @client.request("GET", "/v1/events/#{URI.encode_www_form_component(id.to_s)}")
      end

      # Returns an Enumerator that auto-paginates across all pages.
      def list(params = {})
        paginate("/v1/events", params)
      end
    end
  end
end
