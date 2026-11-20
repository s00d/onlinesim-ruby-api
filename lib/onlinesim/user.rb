# frozen_string_literal: true

module OnlineSim
  # Account: `client.user`.
  class User
    def initialize(request)
      @request = request
    end

    # Balance in USD: {"balance" => Float, "zbalance" => Float, "income" => Float (when sent)}.
    # `balance` includes the frozen `zbalance` (may be negative): available = balance - max(zbalance, 0).
    def balance
      res = @request.call("getBalance.php", query: { income: 1 })
      out = { "balance" => (Normalize.num(res["balance"]) || 0).to_f, "zbalance" => (Normalize.num(res["zbalance"]) || 0).to_f }
      income = Normalize.num(res["income"])
      out["income"] = income.to_f unless income.nil?
      out
    end

    # Account profile.
    def profile
      @request.call("getProfile.php")["profile"]
    end

    # Top-up orders (paginated, newest first) and the available payment methods.
    def payment_history(page = 1)
      # `paylist` stays as sent: a non-empty JSON array is real data (group ids 0..n), not PHP's empty map.
      @request.call("getPaymentHistory.php", query: { page: page })
    end

    # Set the URL that receives SMS webhooks. Raises ApiError VALIDATION_ERROR for an invalid URL.
    def set_webhook_url(url) # rubocop:disable Naming/AccessorMethodName -- API method name
      @request.call("profile.php", body: { profile: { webhook_url: url } })
      true
    end

    # Remove the webhook URL (also from operations in progress).
    def clear_webhook_url
      @request.call("profile.php", body: { profile: { webhook_url: nil } })
      true
    end

    # Webhook delivery log, newest first, 10 per page (a Laravel paginator Hash).
    def webhook_logs(page = 1)
      @request.call("webhook-logs", query: { page: page })["data"]
    end
  end
end
