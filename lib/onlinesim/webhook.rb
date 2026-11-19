# frozen_string_literal: true

require "json"

# Ruby client for the OnlineSim API. Entry point: OnlineSim::Client.
module OnlineSim
  WEBHOOK_TYPES = %w[receiving_sms rent_sms].freeze

  # Parse an inbound webhook body (`receiving_sms` or `rent_sms`) from a JSON string or an already parsed Hash.
  # Lenient: numeric fields may arrive as strings, missing or malformed fields become nil, unknown fields are dropped.
  # Raises OnlineSim::Error only when the input is not a JSON object at all.
  def self.parse_webhook(payload)
    data = payload
    if payload.is_a?(String)
      begin
        data = JSON.parse(payload)
      rescue JSON::ParserError
        raise Error, "Webhook payload is not valid JSON"
      end
    end
    raise Error, "Webhook payload is not a JSON object" unless data.is_a?(Hash)

    data = data.transform_keys(&:to_s)
    {
      "webhook_type" => WEBHOOK_TYPES.include?(data["webhook_type"]) ? data["webhook_type"] : nil,
      "operation_id" => Normalize.num(data["operation_id"]),
      "user_id" => Normalize.num(data["user_id"]),
      "country_code" => Normalize.num(data["country_code"]),
      "number" => webhook_str(data["number"]),
      "sender" => webhook_str(data["sender"]),
      "message" => webhook_str(data["message"]),
      "code" => webhook_str(data["code"]),
      "time_start" => webhook_str(data["time_start"]),
      "time_left" => Normalize.num(data["time_left"])
    }
  end

  def self.webhook_str(value)
    case value
    when String then value
    when Numeric then value.to_s
    end
  end
  private_class_method :webhook_str
end
