# frozen_string_literal: true

require_relative "wire/version"
require_relative "wire/errors"
require_relative "wire/webhook"
require_relative "wire/client"

# Wire is the top-level namespace for the Wire payment API SDK.
#
#   client = Wire::Client.new("sk_live_...")
#   pi = client.payment_intents.create(amount: 50_000, currency: "MNT")
module Wire
end
