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
#  INSTANTIATE_ARGS::   Args passed to +model.all+ via +instantiate_results+.
#
##############################################################################

module Query::ScopeModules::HighLevelQueries
  attr_reader :need_letters

  # Args accepted by +results+, +result_ids+, +num_results+.  (These are passed
  # through into +select_values+.)
  RESULTS_ARGS = [:limit].freeze

  # Args accepted by +instantiate_results+ (and +paginate+ and +results+ since
  # theycall +instantiate_results+, too).
  INSTANTIATE_ARGS = [:include].freeze

  # Number of results the query returns.
  def num_results(_args = {})
    initialize_query unless initialized?
    @num_results ||= result_ids&.size || 0
  end

  # Array of all results, just ids.
  def result_ids(args = {})
    initialize_query unless initialized?
    expect_args(:result_ids, args, RESULTS_ARGS)
    # includes = args[:include] || []
    @result_ids ||=
      if need_letters
        ids_by_letter
      else
        @scopes.ids
      end
  end

  # Returns an array of ids for each letter that has a record present.
  def ids_by_letter
    @letters = {}
    ids = []
    minimal_query_of_all_records.each do |record|
      id, title = record.values_at(:id, :title)
      letter = title[0, 1]
      @letters[id] = letter.upcase if /[a-zA-Z]/.match?(letter)
      ids << id
    end
    ids
  end

  # Tries to be light about it, by selecting only two values.
  # `list_by` expects `Model[:column]` - it's checking the first four chars.
  def minimal_query_of_all_records
    # Arel.sql("LEFT(#{list_by.to_sql},4)")
    @scopes.select(model[:id], list_by[0..3].as("title")).distinct # .
    # map { |record| record.attributes.symbolize_keys }
  end

  # Array of all results, instantiated.
  def results(args = {})
    initialize_query unless initialized?
    instantiate_args, results_args = split_args(args, INSTANTIATE_ARGS)
    instantiate_results(result_ids(results_args), instantiate_args)
  end

  # Let caller supply results if they happen to have them.  *NOTE*: These had
  # better all be valid instances of +model+ -- no error checking is done!!
  def results=(list)
    @result_ids = list.map(&:id)
    @num_results = list.size
    @results = list.each_with_object({}) do |obj, map|
      map[obj.id] ||= obj
    end
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

  # need_letters is the table and column name we're indexing
  # change - to just t/f, and store the title column on the query class!
  #
  # Make sure we requery if we change the letter field.
  def need_letters=(letters)
    unless [true, false, 1, 0].include?(letters)
      raise("You must pass a Boolean to 'need_letters'.")
    end

    return if need_letters == letters

    @result_ids = nil
    @num_results = nil
    @need_letters = letters
  end

  # Returns a subset of the results (as ids).
  def paginate_ids(pagination_data)
    initialize_query unless initialized?
    ids = result_ids
    if need_letters
      pagination_data.used_letters = @letters.values.uniq
      if (letter = pagination_data.letter)
        ids = ids.select { |id| @letters[id] == letter }
      end
    end
    pagination_data.num_total = ids.size
    ids[pagination_data.from..pagination_data.to] || []
  end

  # Returns a subset of the results (as ActiveRecord instances).
  # (Takes args for +instantiate+.)
  def paginate(pagination_data, args = {})
    initialize_query unless initialized?
    instantiate_results(paginate_ids(pagination_data), args)
  end

  # Instantiate a set of records given as an Array of ids.  Returns a list of
  # ActiveRecord instances in the same order as given.  Optional arguments:
  # +include+:: Tables to eager load (see argument of same name in
  #             ActiveRecord::Base#find for syntax).
  def instantiate_results(ids, args = {})
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
