# encoding: utf-8
class ContentFilter
  class BooleanFilter < ContentFilter
    attr_accessor :on_vals
    attr_accessor :prefs_vals
    attr_accessor :off_val

    def type
      :boolean
    end

    def on?(val)
      val.to_s != off_val.to_s
    end
  end
end
