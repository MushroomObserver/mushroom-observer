# frozen_string_literal: true

#
#  = PatternSearch
#
#  This is a user-facing interface for Query. It allows users to type a bunch
#  of parameters into a single text field - potentially search terms, but also
#  specific params, as key:value pairs. (Search terms are not even required.)
#  PatternSearch class parses the whole string and translates those keys:vals
#  into Query params, which it sends to Query. If there are search terms, it
#  sends those as the `pattern` param.
#
#  For each model that we want to be searchable this way by users, we need to
#  write a separate subclass of PatternSearch, because each set of params is
#  particular to that model. User-facing param names can be whatever's easiest
#  to type and understand, and they are translated, so they do not need to be
#  the same as Query params, even in English. Each subclass has a hash routing
#  the English keys of the user-facing parameter names to the Query param names.
#
#  PatternSearch param values have some differences from Query that require
#  preliminary parsing. Dates accept translated phrases like `yesterday` and
#  `1 month ago`, and some strings, Booleans and enums are more tolerant.
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
#    Base -- Base class: handles everything plus build_query.
#    Parser -- Helper class that parses search string.
#    Term -- Helper class that parses a single term value.
#
################################################################################

module PatternSearch
  # everything is autoloaded via Zeitwerk
end
