# encoding: utf-8
class ContentFilter
  class BooleanFilter < ContentFilter
    attr_accessor :on_vals
    attr_accessor :checked_val
    attr_accessor :off_val

    def type
      :boolean
    end
  end
end
