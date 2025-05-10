# frozen_string_literal: true

class Query::Filter
  class StringFilter < Query::Filter
    def type
      [:string]
    end

    def on?(val)
      val.present?
    end
  end
end
