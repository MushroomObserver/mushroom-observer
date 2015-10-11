# encoding: utf-8

class API
  # Expresses a range of values of any types of objects that can be compared
  class OrderedRange < Range
    attr_accessor :begin, :end

    def initialize(from, to, leave_order = false)
      if !leave_order && switch?(from, to)
        @begin = to
        @end = from
      else
        @begin = from
        @end = to
      end
    end

    def switch?(from, to)
      from.is_a?(AbstractModel) ? from.id > to.id : from > to
    rescue
      false
    end

    def include?(val)
      val >= @begin && val <= @end
    end

    def inspect
      "#{@begin.inspect}..#{@end.inspect}"
    end

    alias_method :to_s, :inspect

    def ==(other)
      other.is_a?(OrderedRange) &&
        other.begin == self.begin &&
        other.end == self.end
    end
  end
end
