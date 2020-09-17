# frozen_string_literal: true

class API2
  # Encapsulates a range of values of any types of objects that can be compared
  class OrderedRange < Range
    attr_accessor :begin, :end

    def initialize(from, to)
      super
      @begin = from
      @end = to
    end

    def reverse!
      @begin, @end = @end, @begin
      self
    end

    def include?(val)
      val >= @begin && val <= @end
    end

    def inspect
      "#{@begin.inspect}..#{@end.inspect}"
    end

    alias to_s inspect

    def ==(other)
      other.is_a?(OrderedRange) &&
        other.begin == self.begin &&
        other.end == self.end
    end
  end
end
