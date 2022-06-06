# frozen_string_literal: true

module PatternSearch
  class Parser
    attr_accessor :incoming_string, :terms

    VAL_REGEX = /
      "([^\\"]+|\\.)*" | '([^\\']+|\\.)*' | ([^\s\\,]+|\\.)+
    /x.freeze
    TERM_REGEX = /
      ^(\S+:)? ( #{VAL_REGEX} (, #{VAL_REGEX})* ) (\s+|$)
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
      # make str mutable because it is modified by parse_next_term
      str = + clean_incoming_string
      last_var = nil
      until str.blank?
        (var, vals) = parse_next_term!(str, last_var)
        term = hash[var] ||= Term.new(var)
        vals.each { |val| term << val }
        last_var = var
      end
      hash.values
    end

    # modifies str
    def parse_next_term!(str, last_var = nil)
      str.sub!(TERM_REGEX, "") ||
        raise(SyntaxError.new(string: str))
      var = Regexp.last_match(1)
      vals = Regexp.last_match(2)
      if var.blank?
        last_var && last_var != :pattern &&
          raise(PatternMustBeFirstError.new(str: str, var: last_var))
        var = "pattern"
      end
      var = var.sub(/:$/, "").to_sym
      [var, parse_vals(vals)]
    end

    def parse_vals(str)
      vals = []
      while str.present?
        str.sub!(VAL_REGEX, "")
        vals << Regexp.last_match.to_s
        str.sub!(/^,/, "")
      end
      vals
    end
  end
end
