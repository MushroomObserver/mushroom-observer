# frozen_string_literal: true

class Query::Filter
  class BooleanFilter < Query::Filter
    attr_accessor :on_vals, :prefs_vals, :off_val

    def type
      :boolean
    end

    def on?(val)
      val.to_s != off_val.to_s
    end
  end
end
