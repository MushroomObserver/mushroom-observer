# Helper methods for turning Query parameters into SQL conditions.
#
# rubocop:disable Metrics/ModuleLength
module Query::Modules::Initialization
  # rubocop:disable Metrics/AbcSize

  attr_accessor :join
  attr_accessor :tables
  attr_accessor :where
  attr_accessor :group
  attr_accessor :order
  attr_accessor :executor

  def initialized?
    @initialized ? true : false
  end

  def initialize_query
    @initialized = true
    @join        = []
    @tables      = []
    @where       = []
    @group       = ""
    @order       = ""
    @executor    = nil
    initialize_title
    initialize_flavor
    initialize_order
  end

  # Make a value safe for SQL.
  def escape(val)
    model.connection.quote(val)
  end

  # Put together a list of ids for use in a "id IN (1,2,...)" condition.
  #
  #   set = clean_id_set(name.children)
  #   @where << "names.id IN (#{set})"
  #
  def clean_id_set(ids)
    result = ids.map(&:to_i).uniq[0, MO.query_max_array].map(&:to_s).join(",")
    result = "-1" if result.blank?
    result
  end

  # Clean a pattern for use in LIKE condition.  Takes and returns a String.
  def clean_pattern(pattern)
    pattern.gsub(/[%'"\\]/) { |x| '\\' + x }.tr("*", "%")
  end

  # Combine args into single parenthesized condition by anding them together.
  def and_clause(*args)
    if args.length > 1
      "(" + args.join(" AND ") + ")"
    else
      args.first
    end
  end

  # Combine args into single parenthesized condition by oring them together.
  def or_clause(*args)
    if args.length > 1
      "(" + args.join(" OR ") + ")"
    else
      args.first
    end
  end

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
  def google_parse(str)
    goods = []
    bads  = []
    if (str = str.to_s.strip_squeeze) != ""
      str.gsub!(/\s+/, " ")
      # Pull off "and" clauses one at a time from the beginning of the string.
      loop do
        if str.sub!(/^-"([^""]+)"( |$)/, "") ||
           str.sub!(/^-(\S+)( |$)/, "")
          bads << Regexp.last_match(1)
        elsif str.sub!(/^(("[^""]+"|\S+)( OR ("[^""]+"|\S+))*)( |$)/, "")
          str2 = Regexp.last_match(1)
          or_strs = []
          while str2.sub!(/^"([^""]+)"( OR |$)/, "") ||
                str2.sub!(/^(\S+)( OR |$)/, "")
            or_strs << Regexp.last_match(1)
          end
          goods << or_strs
        else
          raise("Invalid search string syntax at: '#{str}'") if str != ""

          break
        end
      end
    end
    GoogleSearch.new(
      goods: goods,
      bads:  bads
    )
  end

  # Put together a bunch of SQL conditions that describe a given search.
  def google_conditions(search, field)
    goods = search.goods
    bads  = search.bads
    ands = []
    ands += goods.map do |good|
      or_clause(*good.map { |str| "#{field} LIKE '%#{clean_pattern(str)}%'" })
    end
    ands += bads.map { |bad| "#{field} NOT LIKE '%#{clean_pattern(bad)}%'" }
    [ands.join(" AND ")]
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

  # Add a join condition if it doesn't already exist.  There are two forms:
  #
  #   # Add join from root table to the given table:
  #   add_join(:observations)
  #     => join << :observations
  #
  #   # Add join from one table to another: (will create join from root to
  #   # first table if it doesn't already exist)
  #   add_join(:observations, :names)
  #     => join << {:observations => :names}
  #   add_join(:names, :descriptions)
  #     => join << {:observations => {:names => :descriptions}}
  #
  def add_join(*args)
    @join.add_leaf(*args)
  end

  # Same as add_join but can provide chain of more than two tables.
  def add_joins(*args)
    if args.length == 1
      @join.add_leaf(args[0])
    elsif args.length > 1
      while args.length > 1
        @join.add_leaf(args[0], args[1])
        args.shift
      end
    end
  end

  # Join parameter needs to be converted into an include-style "tree".  It just
  # evals the string, so the syntax is almost identical to what you're used to:
  #
  #   ":table, :table"
  #   "table: :table"
  #   "table: [:table, {table: :table}]"
  #
  def add_join_from_string(val)
    @join += val.map do |str|
      # TODO: make sure val does not originate from user! where is this used?
      # rubocop:disable Security/Eval
      str.to_s.index(" ") ? eval(str) : str
    end
  end

  # Safely add to :where in +args+.  Dups <tt>args[:where]</tt>, casts it into
  # an Array, and returns the new Array.
  def extend_where(args)
    extend_arg(args, :where)
  end

  # Safely add to :join in +args+.  Dups <tt>args[:join]</tt>, casts it into
  # an Array, and returns the new Array.
  def extend_join(args)
    extend_arg(args, :join)
  end

  # Safely add to +arg+ in +args+.  Dups <tt>args[arg]</tt>, casts it into
  # an Array, and returns the new Array.
  def extend_arg(args, arg)
    case old_arg = args[arg]
    when Symbol, String
      args[arg] = [old_arg]
    when Array
      args[arg] = old_arg.dup
    else
      args[arg] = []
    end
  end
end
