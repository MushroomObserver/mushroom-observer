##############################################################################
#
#  :section: High-Level Queries
#
#  Note that most of these methods accept a few optional arguments.  For
#  example, all methods that return instantiated results accept +:include+
#  which is passed in to <tt>model.all</tt>.
#
#  join::           Add extra join clause(s) to query.
#  where::          Add extra condition(s) to query.
#  limit::          Put a limit on the number of results from the raw query.
#  include::        Eager-load these associations when instantiating results.
#
#  Add additional arguments to the three "global" Arrays immediately below:
#
#  RESULTS_ARGS::       Args passed to +select_values+ via +result_ids+.
#  PAGINATE_ARGS::      Args passed to +paginate_ids+.
#  INSTANTIATE_ARGS::   Args passed to +model.all+ via +instantiate+.
#
##############################################################################

module Query::Modules::HighLevelQueries
  attr_accessor :need_letters

  # Args accepted by +results+, +result_ids+, +num_results+.  (These are passed
  # through into +select_values+.)
  RESULTS_ARGS = [:join, :where, :limit, :group].freeze

  # Args accepted by +paginate+ and +paginate_ids+.
  PAGINATE_ARGS = [].freeze

  # Args accepted by +instantiate+ (and +paginate+ and +results+ since they
  # call +instantiate+, too).
  INSTANTIATE_ARGS = [:include].freeze

  # Number of results the query returns.
  def num_results(args = {})
    @num_results ||=
      if @result_ids
        @result_ids.count
      else
        rows = select_rows(args.merge(select: "count(*)"))
        begin
          rows[0][0].to_i
        rescue StandardError
          0
        end
      end
  end

  # Array of all results, just ids.
  def result_ids(args = {})
    expect_args(:result_ids, args, RESULTS_ARGS)
    @result_ids ||=
      if !need_letters
        select_values(args).map(&:to_i)
      else
        # Include first letter of paginate-by-letter field right away; there's
        # typically no avoiding it.  This optimizes away an extra query or two.
        @letters = map = {}
        ids = []
        select = "DISTINCT #{model.table_name}.id, LEFT(#{need_letters},4)"
        select_rows(args.merge(select: select)).each do |id, letter|
          letter = letter[0, 1]
          map[id.to_i] = letter.upcase if /[a-zA-Z]/.match?(letter)
          ids << id.to_i
        end
        ids
      end
  end

  # Array of all results, instantiated.
  def results(args = {})
    instantiate_args, results_args = split_args(args, INSTANTIATE_ARGS)
    instantiate(result_ids(results_args), instantiate_args)
  end

  # Let caller supply results if they happen to have them.  *NOTE*: These had
  # better all be valid instances of +model+ -- no error checking is done!!
  def results=(list)
    @result_ids = list.map(&:id)
    @num_results = list.count
    @results = list.inject({}) do |map, obj|
      map[obj.id] ||= obj
      map
    end
    list
  end

  # Let caller supply results if they happen to have them.  *NOTE*: These had
  # better all be valid Integer ids -- no error checking is done!!
  def result_ids=(list)
    @result_ids = list
    @num_results = list.count
  end

  # Get index of a given record / id in the results.
  def index(arg, args = {})
    if arg.is_a?(ActiveRecord::Base)
      result_ids(args).index(arg.id)
    else
      result_ids(args).index(arg.to_s.to_i)
    end
  end

  # Make sure we requery if we change the letter field.
  def need_letters=(letters)
    if !letters.is_a?(String)
      raise "You must pass a SQL expression to 'need_letters'."
    elsif need_letters != letters
      @result_ids = nil
      @num_results = nil
      @need_letters = letters
    end
  end

  # Returns a subset of the results (as ids).  Optional arguments:
  # (Also accepts args for
  def paginate_ids(paginator, args = {})
    results_args, args = split_args(args, RESULTS_ARGS)
    expect_args(:paginate_ids, args, PAGINATE_ARGS)

    # Get list of letters used in results.
    if need_letters
      @result_ids = nil
      @num_results = nil
      result_ids(results_args)
      map = @letters
      paginator.used_letters = map.values.uniq

      # Filter by letter. (paginator keeps letter upper case, as do we)
      if letter = paginator.letter
        @result_ids = @result_ids.select { |id| map[id] == letter }
        @num_results = @result_ids.count
      end
      paginator.num_total = num_results(results_args)
      @result_ids[paginator.from..paginator.to] || []
    else
      # Paginate remaining results.
      paginator.num_total = num_results(results_args)
      results_args[:limit] = "#{paginator.from},#{paginator.num_per_page}"
      result_ids(results_args) || []
    end
  end

  # Returns a subset of the results (as ActiveRecord instances).
  # (Takes same args as both +instantiate+ and +paginate_ids+.)
  def paginate(paginator, args = {})
    paginate_args, instantiate_args = split_args(args, PAGINATE_ARGS)
    instantiate(paginate_ids(paginator, paginate_args), instantiate_args)
  end

  # Instantiate a set of records given as an Array of ids.  Returns a list of
  # ActiveRecord instances in the same order as given.  Optional arguments:
  # +include+:: Tables to eager load (see argument of same name in
  #             ActiveRecord::Base#find for syntax).
  def instantiate(ids, args = {})
    expect_args(:instantiate, args, INSTANTIATE_ARGS)
    @results ||= {}
    ids.map!(&:to_i)
    needed = (ids - @results.keys).uniq
    if needed.any?
      set = clean_id_set(needed)
      # Note that "set" will be truncated to MO.query_max_array if too large.
      # This could result in some results not being returned. (See
      # the reject(&:nil?) clause below.)
      conditions = "#{model.table_name}.id IN (#{set})"
      includes   = args[:include] || []
      model.where(conditions).
        includes(includes).
        to_a.each { |obj| @results[obj.id] = obj }
    end
    ids.map { |id| @results[id] }.reject(&:nil?)
  end

  # Clear out the results cache.  Useful if you need to reload results with
  # more eager loading, or if you need to repaginate something with letters.
  def clear_cache
    @results      = nil
    @result_ids   = nil
    @num_results  = nil
    @letters      = nil
  end

  # Raise an error if caller passed any unexpected arguments.
  def expect_args(method, args, expect) # :nodoc:
    extra_args = args.keys - expect
    unless extra_args.empty?
      raise "Unexpected arguments to Query##{method}: #{extra_args.inspect}"
    end
  end

  # Split up a Hash of arguments, putting all the ones in the given list in
  # the first of two Hash's, and all the rest in the other.  Returns two Hash's.
  def split_args(args, keys_in_first) # :nodoc:
    args1 = {}
    args2 = {}
    args.each do |key, val|
      if keys_in_first.include?(key)
        args1[key] = val
      else
        args2[key] = val
      end
    end
    [args1, args2]
  end
end
