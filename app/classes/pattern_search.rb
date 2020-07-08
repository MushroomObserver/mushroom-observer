# frozen_string_literal: true

#
#  = PatternSearch
#
#  == Usage
#
#    search = PatternSearch::Observation.new(string)
#    unless search.errors.any?
#      render_results(search.query.results)
#    else
#      render_errors(search.errors)
#    end
#
#  == Description
#
#  Accepts strings which are made up of a list of terms separated by spaces.
#  Terms are either bare values or key-value pairs of the form "var:val".
#  Key names must be plain alphanumeric.  Values can be single- or double-
#  quoted, using backslashes to protect special characters.
#
#  Values are parsed according to their type: boolean, integer, date, user,
#  etc.  This is programmed by the derived class, the final product of which
#  is a Query instance.
#
#  == Subclasses
#
#    Base -- Base class: handles everything but build_query.
#    Parser -- Helper class that parses search string.
#    Term -- Helper class that parses a single term value.
#
################################################################################

module PatternSearch
  require_dependency "pattern_search/base"
  require_dependency "pattern_search/parser"
  require_dependency "pattern_search/term"
  require_dependency "pattern_search/errors"
  # (the others should auto-load)
end
