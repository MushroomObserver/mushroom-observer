# encoding: utf-8

module PatternSearch
  class Observation < Base
    def build_query
      self.model  = :Observation
      self.flavor = :all
      self.args   = {}
      for term in parser.terms
        if term.var == :pattern
          self.flavor = :pattern_search
          args[:pattern] = term.parse_pattern
        elsif term.var == :user
          args[:users] = term.parse_list_of_users
        elsif term.var == :date
          args[:date] = term.parse_date_range
        elsif term.var == :specimen
          args[:has_specimen] = term.parse_pattern
        else
          fail BadObservationTermError.new(term: term)
        end
      end
    end
  end
end
