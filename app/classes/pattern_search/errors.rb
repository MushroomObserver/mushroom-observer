# encoding: utf-8

module PatternSearch
  class Error < Exception
    attr_accessor :args
    def initialize(args)
      self.args = args
    end
  end

  class SyntaxError < Error
    def to_s
      "Syntax error in pattern at #{args[:string].inspect}."
    end
  end

  class BadObservationTermError < Error
    def to_s
      "Unexpected term in observation search, #{args[:term].var.inspect}."
    end
  end

  class MissingValueError < Error
    def to_s
      "Missing value for #{args[:var].inspect}."
    end
  end

  class TooManyValuesError < Error
    def to_s
      "Term #{args[:var].inspect} occurs more than once."
    end
  end

  class BadBooleanError < Error
    def to_s
      "Invalid value for #{args[:var].inspect}, #{args[:val].inspect}, expect \"1\", \"0\", \"yes\", \"no\", \"true\", \"false\"."
    end
  end

  class BadUserError < Error
    def to_s
      "Invalid or unrecognized value for #{args[:var].inspect}, #{args[:val].inspect}, expected user id, login or name."
    end
  end

  class BadDateRangeError < Error
    def to_s
      "Invalid value for #{args[:var].inspect}, #{args[:val].inspect}, expected date or date range of form YYYY, YYYY-YYYY, YYYY-MM, YYYY-MM-YYYY-MM, YYYY-MM-DD, YYYY-MM-DD-YYYY-MM-DD, MM, MM-MM or MM-DD-MM-DD."
    end
  end
end
