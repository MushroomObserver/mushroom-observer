# encoding: utf-8

module PatternSearch
  class Base
    attr_accessor :errors
    attr_accessor :parser

    attr_accessor :model
    attr_accessor :flavor
    attr_accessor :args
    attr_accessor :query

    def initialize(string)
      self.errors = []
      self.parser = PatternSearch::Parser.new(string)
      build_query
      self.query = Query.lookup(model, flavor, args)
    rescue Error => e
      errors << e
    end
  end
end
