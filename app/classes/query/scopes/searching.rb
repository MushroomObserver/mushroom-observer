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
  #   search = google_parse(search_string)
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
  def add_pattern_condition
    return if params[:pattern].blank?

    @title_tag = :query_title_pattern_search
    add_search_condition(search_fields, params[:pattern])
  end

  def add_search_condition(model, col, val, *)
    return if val.blank?

    @scopes = model.all
    search = google_parse(val)
    add_google_conditions_good(search, model, col)
    add_google_conditions_bad(search, model, col)
    add_joins(*)
    @scopes.to_sql
  end

  def google_parse(str)
    goods = []
    bads  = []
    if (str = str.to_s.strip_squeeze) != ""
      str.gsub!(/\s+/, " ")
      loop do
        google_parse_one_clause(str, goods, bads) && break
      end
    end
    GoogleSearch.new(
      goods: goods,
      bads: bads
    )
  end

  # Put together a bunch of AR conditions that describe a given search.
  # needs an OR in here if not the first one
  def add_google_conditions_good(search, model, col)
    search.goods.each do |good|
      parts = *good # break up phrases
      ors = model.arel_table[col].matches(clean_pattern(parts.shift))
      parts.each do |str|
        ors = ors.or(model.arel_table[col].matches(clean_pattern(str)))
      end
    end
  end

  def add_google_conditions_bad(search, model, col)
    search.bads.each do |bad|
      @scopes = @scopes.where(
        model.arel_table[col].does_not_match(clean_pattern(bad))
      )
    end
  end

  # ----------------------------------------------------------------------------

  private

  # Pull off one "and" clause from the beginning of the string.
  def google_parse_one_clause(str, goods, bads)
    if str.sub!(/^-"([^"]+)"( |$)/, "") ||
       str.sub!(/^-(\S+)( |$)/, "")
      bads << Regexp.last_match(1)
    elsif str.sub!(/^(("[^"]+"|\S+)( OR ("[^"]+"|\S+))*)( |$)/, "")
      str2 = Regexp.last_match(1)
      or_strs = []
      while str2.sub!(/^"([^"]+)"( OR |$)/, "") ||
            str2.sub!(/^(\S+)( OR |$)/, "")
        or_strs << Regexp.last_match(1)
      end
      goods << or_strs
    else
      raise("Invalid search string syntax at: '#{str}'") if str != ""

      return true
    end
    false
  end

  # Simple class to hold the results of +google_parse+.  It just has two
  # attributes, +goods+ and +bads+.
  class GoogleSearch
    attr_accessor :goods, :bads

    def initialize(args = {})
      @goods = args[:goods]
      @bads = args[:bads]
    end

    def blank?
      @goods.none? && @bads.none?
    end
  end
end
