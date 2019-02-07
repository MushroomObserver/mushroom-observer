module PatternSearch
  class Parser
    attr_accessor :incoming_string
    attr_accessor :terms

    VAL_REGEX = /
      "([^\\\"]+|\\.)*" | '([^\\\']+|\\.)*' | ([^\s\\,]+|\\.)+
    /x.freeze
    TERM_REGEX = /
      ^(\w+:)? ( #{VAL_REGEX} (, #{VAL_REGEX})* ) (\s+|$)
    /x.freeze

    def initialize(string)
      self.incoming_string = string
      self.terms = parse_incoming_string
    end

    def clean_incoming_string
      incoming_string.strip.gsub(/\s+/, " ")
    end

    def parse_incoming_string
      hash = {}
      str = clean_incoming_string
      until str.blank?
        (var, val) = parse_next_term!(str)
        term = hash[var] ||= Term.new(var)
        term << val
      end
      hash.values
    end

    def parse_next_term!(str)
      str.sub!(TERM_REGEX, "") ||
        raise(SyntaxError.new(string: str))
      var = Regexp.last_match(1)
      val = Regexp.last_match(2)
      var = "pattern" if var.blank?
      var = var.sub(/:$/, "").to_sym
      [var, val]
    end
  end
end
