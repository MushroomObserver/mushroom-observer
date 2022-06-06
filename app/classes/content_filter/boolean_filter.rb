# frozen_string_literal: true

class ContentFilter
  class BooleanFilter < ContentFilter
    attr_accessor :on_vals, :prefs_vals, :off_val

    def type
      :boolean
    end

    def on?(val)
      val.to_s != off_val.to_s
    end
  end
end
