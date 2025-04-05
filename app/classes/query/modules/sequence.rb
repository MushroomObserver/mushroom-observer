# frozen_string_literal: true

##############################################################################
#
#  :section: Sequence
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
end
