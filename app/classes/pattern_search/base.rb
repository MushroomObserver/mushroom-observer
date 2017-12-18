# encoding: utf-8

module PatternSearch
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
      for term in parser.terms
        param = params[term.var]
        if term.var == :pattern
          self.flavor = :pattern_search
          args[:pattern] = term.parse_pattern
        elsif param
          query_param, parse_method = param
          args[query_param] = term.send(parse_method)
        else
          fail BadTermError.new(term: term, type: model.type_tag,
                                help: help_message)
        end
      end
    end

    def help_message
      "#{:pattern_search_terms_help.l}\n" + params.keys.map do |arg|
        "* *#{arg}*: #{ :"#{model.type_tag}_term_#{arg}".l }"
      end.join("\n")
    end
  end
end
