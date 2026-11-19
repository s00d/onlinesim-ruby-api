# frozen_string_literal: true

module OnlineSim
  # Client-side normalisation of server quirks, shared by the sections and `parse_webhook`.
  module Normalize
    module_function

    # PHP sends an empty map as `[]`: return `{}` for it (and for anything that is not a Hash).
    def map(value)
      value.is_a?(Hash) ? value : {}
    end

    # Number from a number or a numeric string ("1442.330"); nil when missing or not numeric.
    def num(value)
      case value
      when Integer then value
      when Float then value.finite? ? value : nil
      when String
        text = value.strip
        return nil if text.empty?

        Integer(text, exception: false) || Float(text, exception: false)&.then { |f| f.finite? ? f : nil }
      end
    end
  end
end
