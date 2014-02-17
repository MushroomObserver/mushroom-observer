# encoding: utf-8

module PatternSearch
  class Parser
    attr_accessor :incoming_string
    attr_accessor :terms

    TERM_REGEX = /^(\w+:)? ( "([^\\\"]+|\\.)*" | '([^\\\']+|\\.)*' | ([^\s\\]+|\\.)+ ) (\s+|$)/x

    def initialize(string)
      self.incoming_string = string
      self.terms = parse_incoming_string
    end

    def clean_incoming_string
      incoming_string.strip.gsub(/\s+/, ' ')
    end

    def parse_incoming_string
      hash = {}
      str = clean_incoming_string
      while !str.blank?
        (var, val) = parse_next_term!(str)
        term = hash[var] ||= Term.new(var)
        term << term.dequote(val)
      end
      return hash.values
    end

    def parse_next_term!(str)
      str.sub!(TERM_REGEX, '') or
        raise SyntaxError.new(:string => str)
      var, val = $1, $2
      var = 'pattern' if var.blank?
      var = var.sub(/:$/,'').to_sym
      return [var, val]
    end
  end
end
