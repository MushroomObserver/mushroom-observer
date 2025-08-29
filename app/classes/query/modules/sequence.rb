# frozen_string_literal: true

##############################################################################
#
#  :module: Sequence
#
#  Query keeps track of "where you are in the query".  Browsing through
#  filtered results, if you visit a "show" page, you can continue navigating
#  through the same results via the "next" and "prev" links on the show page,
#  within the same query — as if you were paging through results in the index.
#
#  NOTE: The next and prev sequence operators always grab the entire set of
#  result_ids.  No attempt is made to reduce the query.  NOTE: we might be
#  able to if we can turn the ORDER clause into an upper/lower bound.
#
#  The first and last sequence operators ignore result_ids.  However, they are
#  able to execute optimized queries that return only the first or last result.
#
#  == Instance Methods:
#
#  Methods for moving forward/back up/down within Query results.
#  Used on show pages of individual records.
#
#  current_id=::  Set current place in results by id.
#  current=::     Same as above, but accepts record instances.
#  current(*)     Current place in results, with record instantiated.
#  reset::        Reset current place in results to place last set (via above).
#  current::      Move to the current place
#  first::        Move to the first record in the set, as sorted.
#  previous::
#  next::
#  last::
#
#  Sequence operators let you use the query as a pseudo-iterator:  (Note, these
#  are somewhat more subtle than shown here, as nested queries may require the
#  creation of new query instances.  See the section on nested queries below.)
#
#    query = Query.lookup(:Observation)
#    query.current = @observation
#    next  = query.current if query.next
#    this  = query.current if query.prev
#    prev  = query.current if query.prev
#    first = query.current if query.first
#    last  = query.current if query.last
#
#  Query knows how to work with PaginationData:
#
#    # In controller:
#    query = create_query(:Name)
#    @pagination_data = number_pagination_data
#    @names = query.paginate(@pagination_data)
#
#    # Or if you want to paginate by letter first, then page number:
#    query = create_query(:Name)
#    query.need_letters = 'names.sort_name'
#    @pagination_data = letter_pagination_data
#    @names = query.paginate(@pagination_data)
#
#  == Sequence Operators
#
#  The "correct" usage of the sequence operators is subtle and inflexible due
#  to the complexities of the query potentially being nested.  This is how it
#  is designed to work:
#
#    query = Query.lookup(:Image)
#
#    # Note that query.next *MAY* return a clone.
#    if new_query = query.next
#      puts "Next image is: " + new_query.current_id
#    else
#      puts "No more images."
#    end
#
#    # Must reset otherwise query.prev just goes back to original place.
#    query.reset
#    if new_query = query.prev
#      puts "Previous image is: " + new_query.current_id
#    else
#      puts "No more images."
#    end
#
#    # Note: query.last works the same.
#    if new_query = query.first
#      puts "First image is: " + new_query.current_id
#    else
#      puts "There are no matching images!"
#    end
#
#
###############################################################################

module Query::Modules::Sequence
  # Current place in results, as an id.  (Returns nil if not set yet.)
  attr_reader :current_id

  # Set current place in results; takes id (String or Integer).
  def current_id=(id)
    @save_current_id = @current_id = id.to_s.to_i
  end

  # Reset current place in results to place last given in a "current=" call.
  def reset
    @current_id = @save_current_id
  end

  # Current place in results, instantiated.  (Returns nil if not set yet.)
  def current(*)
    @current_id ? instantiate_results([@current_id], *).first : nil
  end

  # Set current place in results; takes instance or id (String or Integer).
  def current=(arg)
    if arg.is_a?(model)
      @results ||= {}
      @results[arg.id] = arg
      self.current_id = arg.id
    else
      self.current_id = arg
    end
  end

  # Move to first place.
  def first
    new_self = self
    id = new_self.result_ids.first
    if id.positive?
      @current_id = id
    else
      new_self = nil
    end
    new_self
  end

  def first_id
    return nil unless result_ids.length

    result_ids.first
  end

  # Move to previous place.
  def prev
    new_self = self
    index = result_ids.index(current_id)
    return nil unless index

    if index.positive?
      @current_id = result_ids[index - 1]
    else
      new_self = nil
    end
    new_self
  end

  # Returns the previous id, or nil, without changing the query.
  # Must set current_id= first
  def prev_id
    index = result_ids.index(current_id)
    return nil unless index&.positive?

    result_ids[index - 1]
  end

  # Move to next place.
  def next
    new_self = self
    index = result_ids.index(current_id)
    return nil unless index

    if index < result_ids.length - 1
      @current_id = result_ids[index + 1]
    else
      new_self = nil
    end
    new_self
  end

  # Returns the previous id, or nil, without changing the query.
  # Must set current_id= first
  def next_id
    index = result_ids.index(current_id)
    return nil unless index && index < result_ids.length - 1

    result_ids[index + 1]
  end

  # Move to last place.
  def last
    new_self = self
    id = new_self.result_ids.last
    if id.positive?
      @current_id = id
    else
      new_self = nil
    end
    new_self
  end

  def last_id
    return nil unless result_ids.length

    result_ids.last
  end
end
