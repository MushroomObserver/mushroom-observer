# frozen_string_literal: true

class ContentFilter
  class StringFilter < ContentFilter
    def type
      [:string]
    end

    def on?(val)
      val.present?
    end

    def sql_conditions(query, model, vals)
      vals.map { |val| sql_condition(query, model, val) }.join(" OR ")
    end

    def scope_conditions(query, model, vals)
      return unless vals.length.positive?

      # Start without `or`, chain subsequent conditions
      conditions = sql_condition(query, model, vals.shift)
      vals.each do |val|
        conditions = conditions.or(sql_condition(query, model, val))
      end
    end
  end
end
