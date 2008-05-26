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
      logger.warn("SequenceState.initialize: loading from seq_states") if logger
      @current_id = key_state[:current_id]
      @current_index = key_state[:current_index]
      @next_id = key_state[:next_id]
      @prev_id = key_state[:prev_id]
      @query = key_state[:query]
      @query_type = key_state[:query_type]
      @access_count = (key_state[:access_count] || 0) + 1
    else
      logger.warn("SequenceState.initialize: making shit up: #{id}, #{search_state.query_type}") if logger
      if query_type != search_state.query_type && search_state.query_type == :observations
        id = params[:obs].to_i
        logger.warn("SequenceState.initialize: query_type mismatch") if logger
      else
        logger.warn("SequenceState.initialize: query_type is ok") if logger
      end
      @current_id = id
      @current_index = nil
      @next_id = nil
      @prev_id = nil
      @query_type = search_state.query_type # Can override query_type
      @access_count = 0
    end
  end

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
  
  def have_index(index)
    result = false
    if @cache
      result = ((@start_index <= index) && (index < @start_index + @count))
    end
    result
  end
  
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
