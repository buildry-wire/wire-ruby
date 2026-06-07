# frozen_string_literal: true

module Wire
  module Resources
    # Base provides shared helpers for resource classes, notably the
    # cursor auto-pagination enumerator.
    class Base
      def initialize(client)
        @client = client
      end

      private

      # paginate returns an Enumerator that yields every item across pages,
      # following has_more via starting_after. It is lazy: pages are fetched
      # only as the caller iterates.
      #
      #   client.charges.list(limit: 50).each { |ch| ... }
      #   client.charges.list.to_a
      def paginate(path, params)
        params ||= {}
        limit = params[:limit] || params["limit"]
        after = params[:starting_after] || params["starting_after"] || ""

        Enumerator.new do |yielder|
          loop do
            page = @client.request(
              "GET", path,
              query: { "limit" => limit, "starting_after" => (after unless after.to_s.empty?) }
            )
            data = page["data"] || []
            data.each do |item|
              after = item["id"]
              yielder << item
            end
            break if !page["has_more"] || data.empty?
          end
        end
      end
    end
  end
end
