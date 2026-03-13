# frozen_string_literal: true

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
#   search = Search.new(phrase: search_string)
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
class SearchParams
  attr_reader :phrase, :goods, :bads

  def initialize(args = {})
    @phrase = args[:phrase]
    @goods, @bads = google_parse(@phrase)
  end

  def blank?
    @goods.none? && @bads.none?
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
    [goods, bads]
  end

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
end
