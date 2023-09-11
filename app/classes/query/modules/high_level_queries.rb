# frozen_string_literal: true

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
#  INSTANTIATE_ARGS::   Args passed to +model.all+ via +instantiate+.
#
##############################################################################

module Query::Modules::HighLevelQueries
  attr_accessor :need_letters

  # Args accepted by +results+, +result_ids+, +num_results+.  (These are passed
  # through into +select_values+.)
  RESULTS_ARGS = [:join, :where, :limit, :group].freeze

  # Args accepted by +instantiate+ (and +paginate+ and +results+ since they
  # call +instantiate+, too).
  INSTANTIATE_ARGS = [:include].freeze

  # Number of results the query returns.
  def num_results(_args = {})
    @num_results ||= result_ids&.size || 0
  end

  # Array of all results, just ids.
  def result_ids(args = {})
    expect_args(:result_ids, args, RESULTS_ARGS)
    @result_ids ||=
      if need_letters
        # Include first letter of paginate-by-letter field right away; there's
        # typically no avoiding it.  This optimizes away an extra query or two.
        @letters = {}
        ids = []
        select = "DISTINCT #{model.table_name}.id, LEFT(#{need_letters},4)"
        select_rows(args.merge(select: select)).each do |id, letter|
          letter = letter[0, 1]
          @letters[id.to_i] = letter.upcase if /[a-zA-Z]/.match?(letter)
          ids << id.to_i
        end
        ids
      else
        select_values(args).map(&:to_i)
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
    @num_results = list.size
    @results = list.each_with_object({}) do |obj, map|
      map[obj.id] ||= obj
    end
    list
  end

  # Let caller supply results if they happen to have them.  *NOTE*: These had
  # better all be valid Integer ids -- no error checking is done!!
  def result_ids=(list)
    @result_ids = list
    @num_results = list.size
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
    unless letters.is_a?(String)
      raise("You must pass a SQL expression to 'need_letters'.")
    end

    return if need_letters == letters

    @result_ids = nil
    @num_results = nil
    @need_letters = letters
  end

  # Returns a subset of the results (as ids).
  def paginate_ids(paginator)
    ids = result_ids
    if need_letters
      paginator.used_letters = @letters.values.uniq
      if (letter = paginator.letter)
        ids = ids.select { |id| @letters[id] == letter }
      end
    end
    paginator.num_total = ids.size
    ids[paginator.from..paginator.to] || []
  end

  # Returns a subset of the results (as ActiveRecord instances).
  # (Takes args for +instantiate+.)
  def paginate(paginator, args = {})
    instantiate(paginate_ids(paginator), args)
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
    add_needed_to_results(needed: needed, args: args) if needed.any?
    ids.filter_map { |id| @results[id] }
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
    return if extra_args.empty?

    raise("Unexpected arguments to Query##{method}: #{extra_args.inspect}")
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

  ##############################################################################

  private

  def add_needed_to_results(needed:, args:)
    includes = args[:include] || []
    model.
      # NOTE: limited_id_set truncates ids to MO.query_max_array if too large.
      # This could result in some results not being returned. (See
      # the reject(&:nil?) clause below.)
      where(id: limited_id_set(needed)).
      includes(includes).
      to_a.each { |obj| @results[obj.id] = obj }
  end
end
