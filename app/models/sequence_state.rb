#
# This documentation is still under construction...
#
# Supported query_types:
#   :images
#   ...
#
# Usage of session[]:
#   session[:search_states][:count]    Number of states allocated.
#   session[:search_states][0...]      State for a particular search.
#     :title
#     :conditions
#     :order
#     :source
#     :query_type
#     :access_count     Number of times used.
#     :timestamp        Time last used.
# 
#   session[:seq_states][:count]    Number of states allocated.
#   session[:seq_states][0...]      State for a particular search.
#     :current_id
#     :current_index
#     :next_id
#     :prev_id
#     :query
#     :query_type
#     :access_count     Number of times used.
#     :timestamp        Time last used.
# 
# Usage of params[]:
#   :search_seq
#   :seq_key
#   :id
#   :obs
# 
# Methods in application_controller:
#   store_search_state(state)     Stores search state in session.
#   store_seq_state(state)        Stores sequence state in session.
# 
# Instance vars:
#   @key              Copy of data stored in session[:seq_states][@key].
#   @current_id
#   @current_index
#   @next_id
#   @prev_id
#   @query
#   @query_type
#   @access_count
#   @timestamp
# 
#   @connection       Database connection, e.g. Name.connection.
#   @cache            Simple list of object ids (integers).
#   @start_index      Index of first object in cache.
#   @count            Number of objects in cache.  (Same as @cache.length.)
#   @has_full_cache   Does cache contain entire query?
#   @logger           Optional: logs...
# 
# Model methods:
#   new(session, params, connection, query_type, logger)
#   session_data()
#   query_ids(query, start, count)
#   reload_cache(index, count)
#   have_index(index)
#   index_from_cache(search_id)
#   index_from_id(search_id, index_hint)
#   id_from_index(index)
#   next()
#   prev()
# 
################################################################################

class SequenceState

  attr_accessor :current_id
  attr_accessor :current_index
  attr_accessor :next_id
  attr_accessor :prev_id
  attr_accessor :timestamp
  attr_accessor :key
  attr_accessor :access_count
  attr_reader :query
  attr_reader :query_type

  DEFAULT_CACHE_SIZE = 16

  # Look up sequence state (key in params[:seq_key]), or create new one if none
  # specified/found.  Pass in the controller's +session+ and +params+, a
  # database +connection+ (e.g. <tt>Names.connection</tt>), query type (see
  # top of page for list of supported types), and optional logger.
  def initialize(session, params, connection, query_type, logger=nil)
    session_state = session[:seq_states]
    key = params[:seq_key]
    id = params[:id].to_i
    @timestamp = Time.now.to_i
    if key.nil? # Need a new key
      key = 0
      if session_state
        if session_state[:count]
          key = session_state[:count].to_i + 1
        end
        session_state[:count] = key
      end
    end
    search_state = SearchState.new(session, params, query_type, logger)

    # Need setup
    @key = key.to_s
    @logger = logger
    @query = search_state.query
    @cache = nil
    @has_full_cache = nil
    @start_index = nil
    @count = nil
    @connection = connection
    key_state = session_state && session_state[key]
    if key_state # && (id == key_state[:current_id])
      @current_id = key_state[:current_id]
      @current_index = key_state[:current_index]
      @next_id = key_state[:next_id]
      @prev_id = key_state[:prev_id]
      @query = key_state[:query]
      @query_type = key_state[:query_type]
      @access_count = (key_state[:access_count] || 0) + 1
    else
      if query_type != search_state.query_type && search_state.query_type != :images
        id = params[:obs].to_i
      end
      @current_id = id
      @current_index = nil
      @next_id = nil
      @prev_id = nil
      @query_type = search_state.query_type # Can override query_type
      @access_count = 0
    end
  end

  # Return hash of data stored in session[:seq_states][key].
  def session_data()
    {
      :current_id => @current_id,
      :current_index => @current_index,
      :next_id => @next_id,
      :prev_id => @prev_id,
      :query => @query,
      :query_type => @query_type,
      :access_count => @access_count,
      :timestamp => @timestamp,
    }
  end

  # Query database, returning a simple list of object ids (numbers not strings).
  # This should not be called, since it only partially sets the relevant
  # instance variables -- use reload_cache instead.
  def query_ids(query, start, count)
    result = []
    if start.nil? or count.nil?
      data = @connection.select_all(query)
      @has_full_cache = true
    else
      data = @connection.select_all("#{query} limit #{start}, #{count}")
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
    @cache = query_ids(@query, index, count)
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

  # Move state to the next item
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

  # Move state to the prev item
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
end
