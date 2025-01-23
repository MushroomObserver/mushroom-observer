# frozen_string_literal: true

# Helper methods for adding search conditions to query.
module Query::Scopes::Searching
  # Give search string for notes google-like syntax:
  #   word1 word2     -->  any has both word1 and word2
  #   word1 OR word2  -->  any has either word1 or word2
  #   "word1 word2"   -->  any has word1 followed immediately by word2
  #   -word1          -->  none has word1
  #
  # Note, to conform to google, "OR" must be greedy, thus:
  #   word1 word2 OR word3 word4
  # is interpreted as:
  #   any has (word1 and (either word2 or word3) and word4)
  #
  # Note, the following are not allowed:
  #   -word1 OR word2
  #   -word1 OR -word2
  #
  # The result is an Array of positive asserions and an Array of negative
  # assertions.  Each positive assertion is one or more strings.  One of the
  # fields being searched must contain at least one of these strings out of
  # each assertion.  (Different fields may be used for different assertions.)
  # Each negative assertion is a single string.  None of the fields being
  # searched may contain any of the negative assertions.
  #
  #   search = SearchParams.new(phrase: search_string)
  #   search.goods = [
  #     [ "str1", "or str2", ... ],
  #     [ "str3", "or str3", ... ],
  #     ...
  #   ]
  #   search.bads = [ "str1", "str2", ... ]
  #
  # Example result for "agaricus OR amanita -amanitarita":
  #
  #   search.goods = [ [ "agaricus", "amanita" ] ]
  #   search.bads  = [ "amanitarita" ]
  #
  #  AR: `search_fields` should be defined in the Query class as either
  #  model.arel_table[:column] or a concatenation of columns in parentheses.
  #  e.g. Observation[:notes] or (Observation[:notes] + Observation[:name])
  #
  def add_pattern_condition
    return if params[:pattern].blank?

    @title_tag = :query_title_pattern_search
    add_search_conditions(search_fields, params[:pattern])
  end

  def add_search_conditions(table_columns, val)
    return if val.blank?

    add_google_conditions_good(table_columns, search)
    add_google_conditions_bad(table_columns, search)
    # @scopes.to_sql
  end

  # Put together a bunch of AR conditions that describe what a given search.
  # is looking for. These are ANDS, but grouped parts can be ORS.
  # For example this search string (from QueryTest):
  #   'foo OR bar OR "any*thing" -bad surprise! -"lost boys"'
  # should produce this SQL:
  #   "(x LIKE '%foo%' OR x LIKE '%bar%' OR x LIKE '%any%thing%') " \
  #   "AND x LIKE '%surprise!%' AND x NOT LIKE '%bad%' " \
  #   "AND x NOT LIKE '%lost boys%'"
  #
  def add_google_conditions_good(table_columns, search)
    search.goods.each do |good|
      parts = *good # break up phrases
      # pop the first phrase off to start the condition chain without an `OR`
      ors = table_columns.matches(parts.shift.clean_pattern)
      parts.each do |str|
        # join the parts with `or`
        ors = ors.or(table_columns.matches(str.clean_pattern))
      end
      # Add a where condition for each good (equivalent to `AND`)
      @scopes = @scopes.where(ors)
    end
  end

  # AR conditions for what the search wants to avoid. These are ANDS
  def add_google_conditions_bad(table_columns, search)
    search.bads.each do |bad|
      @scopes = @scopes.where(
        table_columns.does_not_match(bad.clean_pattern)
      )
    end
  end
end
