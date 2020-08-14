# frozen_string_literal: true

module PatternSearch
  # Base class for PatternSearch; handles everything but build_query
  class Base
    attr_accessor :errors
    attr_accessor :parser
    attr_accessor :flavor
    attr_accessor :args
    attr_accessor :query

    def initialize(string)
      self.errors = []
      self.parser = PatternSearch::Parser.new(string)
      build_query
      self.query = Query.lookup(model.name.to_sym, flavor, args)
    rescue Error => e
      errors << e
    end

    def build_query
      self.flavor = :all
      self.args   = {}
      parser.terms.each do |term|
        param = params[term.var]
        if term.var == :pattern
          self.flavor = :pattern_search
          args[:pattern] = term.parse_pattern
        elsif param
          query_param, parse_method = param
          args[query_param] = term.send(parse_method)
        else
          raise(BadTermError.new(term: term,
                                 type: model.type_tag,
                                 help: help_message))
        end
      end
    end

    def help_message
      "#{:pattern_search_terms_help.l}\n#{self.class.terms_help}"
    end

    def self.terms_help
      params.keys.map do |arg|
        "* *#{arg}*: #{:"#{model.type_tag}_term_#{arg}".l}"
      end.join("\n")
    end
  end
end
