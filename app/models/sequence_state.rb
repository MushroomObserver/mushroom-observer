#
#  This class represents the current location within the results of a search
#  or index.  For example, if you do an index of a user's observations, this
#  could be used to keep track of which observation you are on within that set
#  of observations.
#
#  Typically, you would create a SearchState first (representing the query for
#  a given users's observations, for example), then place its ID in
#  <tt>params[:search_seq]</tt>, then call SequenceState.lookup().  Then you
#  are free to pass the sequence state around (via params[:seq_key]) to tell
#  actions where you are within that query's results.  For example, you can
#  move to the next or previous item by calling +sequence_state.next+ or
#  +sequence_state.prev+.
#
#  NOTE: Don't forget to save your state after doing anything with it.  This
#  applies to +lookup+, +next+ and +prev+.  If you do not, it will not update
#  usage statistics, and it may potentially be culled by our garbage sweeper.
#
#  Usage:
#    # Within controller...
#    def index_of_users_observations
#      @user = User.find(params[:id])
#      # Create new search.
#      @search_state = SearchState.lookup({:user => @user}, :user_observations)
#      @search_state.save
#      @observations = Observation.find_by_sql(@search_state.query)
#      render(:action => 'observation_index')
#    end
#    def show_observation
#      # Grab search from params[:search_seq].
#      @search_state = SearchState.lookup(params, :default_query_type)
#      @search_state.save
#      # Grab sequence from params[:seq_key] (or create if not done so yet).
#      @sequence_state = SequenceState.lookup(params, :default_query_type)
#      @sequence_state.save
#    end
#
#    # Within index view...
#    for observation in @observations
#      link_to(observation.title,
#        :action => 'show_observation',
#        :id => observation.id,
#        :search_seq => @search_state.id # (pass search into show_observation)
#      )
#    end
#
#    # Within show_observation view...
#    link_to('Prev'
#      :action => 'show_observation',
#      :id => @sequence_state.prev.current_id,
#      :search_seq => @search_state.id, # (pass search into show_observation)
#      :seq_key => @sequence_state.id   # (keep track of place within search)
#    )
#    link_to('Next'
#      :action => 'show_observation',
#      :id => @sequence_state.next.current_id,
#      :search_seq => @search_state.id, # (pass search into show_observation)
#      :seq_key => @sequence_state.id   # (keep track of place within search)
#    )
#
#  Supported query_types:
#    :species_list_observations
#    :name_observations
#    :synonym_observations
#    :other_observations
#    :observations
#    :images
#    :rss_logs
#
#  Usage of params[]:
#    :search_seq         ID of SearchState we're using to keep track of query parameters.
#    :seq_key            ID of SequenceState we're using to keep track on place within search.
#    :id                 ID of item we're showing.
#    :obs                ???
#  
#  Attributes in database:
#    query_type          Query type, e.g. :image.
#    query               SQL statement.
#    current_index       Current index in list.
#    current_id          ID of current item in list.
#    next_id             ID of next item in list.
#    prev_id             ID of previous item in list.
#    access_count        Number of times used.
#    timestamp           Last time used.
#  
#  Instance vars:
#    @cache              Simple list of object ids (integers).
#    @start_index        Index of first object in cache.
#    @count              Number of objects in cache.  (Same as @cache.length.)
#    @has_full_cache     Does cache contain entire query?
#    @logger             Optional logger.
#  
#  Model methods:
#    SequenceState.lookup(params, query_type, logger)
#                            Look up a sequence state, creating one if necessary.
#    state.next              Go to next item.
#    state.prev              Go to previous item.
#    state.log(message)      Add debug message to server log (given in lookup).
#    SequenceState.cleanup   Clean out old states.
#
#  Internal methods:
#    query_ids(query, start, count)
#    reload_cache(index, count)
#    have_index(index)
#    index_from_cache(search_id)
#    index_from_id(search_id, index_hint)
#    id_from_index(index)
#  
################################################################################

class SequenceState < ActiveRecord::Base

  DEFAULT_CACHE_SIZE = 16

  # Look up sequence state (id in params[:seq_key]), or create new one if none
  # specified/found.  Pass in the controller's +params+, query type (see top of
  # page for list of supported types), and optional logger.
  def self.lookup(params, query_type, logger=nil)
    # Look up existing state.
    if id = params[:seq_key]
      state = self.find(id)
      state.timestamp = Time.now
      state.access_count += 1
    # Create new state.
    else
      self.cleanup
      search_state = SearchState.lookup(params, query_type, logger)
      state = self.new
      if search_state.query_type != query_type &&
         search_state.query_type != :images
        state.current_id = params[:obs].to_i
      else
        state.current_id = params[:id].to_i
      end
      state.current_index = nil
      state.next_id = nil
      state.prev_id = nil
      state.query = search_state.query
      state.query_type = search_state.query_type # Can override query_type
      state.timestamp = Time.now
      state.access_count = 0
    end
    # Initialize cache.
    @cache = nil
    @has_full_cache = nil
    @start_index = nil
    @count = nil
    @logger = logger
    return state
  end

  # Add debug message to system log.  (logger provided to +lookup+)
  def log(msg)
    @logger.warn(msg) if @logger
  end

  # For backward compatibility: wrap this attribute so it returns a symbol.
  def query_type
    val = super
    val = nil if val == ''
    val = val.to_sym if val.is_a?(String)
    return val
  end

  # Move state to the next item.
  def next()
    result = self.next_id
    if self.current_index
      next_index = self.current_index + 1
      calc_next = self.id_from_index(next_index) # Next from current index
    else
      self.current_index = self.index_from_id(self.current_id) || 0
      next_index = self.current_index + 1
      calc_next = self.id_from_index(next_index)
      result = calc_next
    end
    if calc_next == result # No change
      self.next_id = self.id_from_index(next_index + 1)
      self.prev_id = self.current_id
      self.current_index = next_index
    else
      # Next based on current_index has changed.
      # If current has a higher index, then do next of that
      # higher index.
      # If current has a lower index, then find next_id's index
      calc_current_index = self.index_from_id(self.current_id) # Current from current index
      if calc_current_index >= self.current_index
        # Base next on current
        self.prev_id = self.current_id
        new_index = calc_current_index + 1
        result = self.id_from_index(new_index)
        self.next_id = self.id_from_index(new_index + 1)
        self.current_index = new_index
     else # Base next on self.next
        self.prev_id = self.current
        self.next_id = self.id_from_index(calc_current_index + 2) # cache's at current
      end
    end
    if result.nil?
      result = self.id_from_index(0)
      self.current_index = 0
      self.prev_id = nil
      self.next_id = self.id_from_index(1)
    end
    self.current_id = result
    result
  end

  # Move state to the prev item.
  def prev()
    result = self.prev_id
    if self.current_index
      prev_index = self.current_index - 1
      calc_prev = self.id_from_index(prev_index) # prev from current index
    else
      self.current_index = self.index_from_id(self.current_id) || 0
      prev_index = self.current_index - 1
      calc_prev = self.id_from_index(prev_index)
      result = calc_prev
    end
    if calc_prev == result # No change
      self.prev_id = self.id_from_index(prev_index - 1)
      self.next_id = self.current_id
      self.current_index = prev_index
    else
      # prev based on current_index has changed.
      # If current has a higher index, then do prev of that
      # higher index.
      # If current has a lower index, then find prev_id's index
      calc_current_index = self.index_from_id(self.current_id) # Current from current index
      if calc_current_index >= self.current_index
        # Base prev on current
        self.next_id = self.current_id
        new_index = calc_current_index - 1
        result = self.id_from_index(new_index)
        self.prev_id = self.id_from_index(new_index - 1)
        self.current_index = new_index
     else # Base prev on self.prev
        self.next_id = self.current
        self.prev_id = self.id_from_index(calc_current_index - 2) # cache's at current
      end
    end
    if result.nil?
      result = self.id_from_index(0)
      self.current_index = 0
      self.prev_id = nil
      self.next_id = self.id_from_index(1)
    end
    self.current_id = result
    result
  end

  # Only keep unused states around for an hour, and used states for a day.
  # This goes through the whole lot, and destroys old ones.
  def self.cleanup
    self.connection.delete %(
      DELETE FROM sequence_states
      WHERE timestamp < DATE_SUB(NOW(), INTERVAL 1 HOUR) AND
            (timestamp < DATE_SUB(NOW(), INTERVAL 1 DAY) OR access_count = 0)
    )
  end

################################################################################

  protected

  # Query database, returning a simple list of object ids (numbers not strings).
  # This should not be called, since it only partially sets the relevant
  # instance variables -- use reload_cache instead.
  # [We should simplify the SQL query to just get the id, call select_values.]
  def query_ids(query, start, count)
    result = []
    if start.nil? or count.nil?
      data = self.class.connection.select_all(query)
      @has_full_cache = true
    else
      data = self.class.connection.select_all("#{query} limit #{start}, #{count}")
      @has_full_cache = false
    end
    for d in data
      id = d['id']
      if id
        result.push(id.to_i)
      end
    end
    result
  end

  # Query database, and populate some or all of cache (depending on the
  # optional +index+ and +count+ arguments).  Cache is a simple list of
  # object ids.  Protects against negative +index+.
  def reload_cache(index=nil, count=nil)
    # For now just load all the ids into the cache.
    # If performance gets bad then we can be smarter
    # about using the info we have like the index or
    # the id
    if index && (index < 0)
      index = 0
    end
    @cache = query_ids(self.query, index, count)
    @start_index = index || 0
    @count = @cache.length
  end

  # Does cache contain index?
  def have_index(index)
    result = false
    if @cache
      result = ((@start_index <= index) && (index < @start_index + @count))
    end
    result
  end

  # Get index of object (id is +search_id+) in cache, or nil if not found.
  def index_from_cache(search_id)
    unless @cache
      reload_cache()
    end
    count = 0
    for id in @cache
      if search_id == id
        return count + @start_index
      end
      count += 1
    end
    nil
  end

  # Get index of object (id is +search_id+).  Searches cache first, then
  # looks near the top, then loads entire query.  Returns index or nil.
  def index_from_id(search_id, index_hint = 0)
    result = index_from_cache(search_id)
    if result.nil?
      reload_cache(index_hint, DEFAULT_CACHE_SIZE)
      # reload_cache()
      result = index_from_cache(search_id)
      if result.nil?
        # Should we try a search from 0 if index_hint != 0?
        reload_cache()
        result = index_from_cache(search_id)
      end
    end
    result
  end

  # Uses cached previous result if available
  # Returns nil if index is out of range
  def id_from_index(index)
    result = nil
    if index >= 0
      unless have_index(index)
        reload_cache(index - 2, 5) # Grab the next/prev window around index
        # reload_cache()
      end
      if have_index(index)
        result = @cache[index - @start_index]
      end
    end
    result
  end
end
