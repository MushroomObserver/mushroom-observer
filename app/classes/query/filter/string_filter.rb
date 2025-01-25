# frozen_string_literal: true

class Query::Filter
  class StringFilter < Query::Filter
    def type
      [:string]
    end

    def on?(val)
      val.present?
    end

    def sql_conditions(query, model, vals)
      vals.map { |val| sql_condition(query, model, val) }.join(" OR ")
    end
  end
end
