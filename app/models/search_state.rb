class SearchState

  attr_accessor :title
  attr_accessor :conditions
  attr_accessor :order
  attr_accessor :source
  attr_accessor :timestamp
  attr_accessor :key
  attr_accessor :access_count
  attr_reader :query_type

  def query()
    result = nil
    order = @order
    case @query_type
    when :species_list_observations
      result = %(
        SELECT o.id, n.search_name
        FROM names n, observations o, observations_species_lists osl, species_lists s
        WHERE n.id = o.name_id and o.id = osl.observation_id and osl.species_list_id = s.id
      )
    when :name_observations
      result = %(
        SELECT o.id, o.when, o.thumb_image_id, o.where, o.location_id,
          u.name, u.login, o.user_id, n.observation_name, o.vote_cache
        FROM observations o, users u, names n
        WHERE n.id = o.name_id and u.id = o.user_id
      )
    when :synonym_observations
      result = %(
        SELECT o.id, o.when, o.thumb_image_id, o.where, o.location_id,
          u.name, u.login, o.user_id, n.observation_name, o.vote_cache
        FROM observations o, users u, names n
        WHERE n.id = o.name_id and u.id = o.user_id and
          (o.vote_cache >= 0 || o.vote_cache is null)
      )
    when :other_observations
      # Matches on non-consensus namings, any vote.
      result = %(
        SELECT o.id, o.when, o.thumb_image_id, o.where, o.location_id,
          u.name, u.login, o.user_id, n.observation_name, g.vote_cache
        FROM observations o, users u, names n, namings g
        WHERE o.id = g.observation_id and
          n.id = o.name_id and u.id = o.user_id and
          o.name_id != g.name_id
      )
    when :observations
      result = "select observations.*, names.search_name
        from names, observations
        left outer join locations on observations.location_id = locations.id
        where observations.name_id = names.id"
    when :images
      result = "select distinct i.*
        from images i, images_observations io, observations o, names n
        where i.id = io.image_id and o.id = io.observation_id and n.id = o.name_id"
      order = order || "i.id"
    else
      result = "select observation_id as id, modified from rss_logs where observation_id is not null and " +
               "modified is not null"
    end
    order = order || "'modified' desc"
    result += " and (#{@conditions})" if @conditions
    result + " order by #{order}"
  end
  
  def initialize(session, params, query_type=:rss_logs, logger=nil)
    session_state = session[:search_states]
    key = params[:search_seq]
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
    @key = key.to_s
    @logger = logger
    @conditions = nil
    @order = nil
    # I'm sure there's a more rubyish way to the following
    key_state = session_state && session_state[key]
    if key_state
      @title = key_state[:title]
      if key_state[:conditions] && (key_state[:conditions] != '')
        @conditions = key_state[:conditions]
      end
      @order = key_state[:order]
      @source = key_state[:source]
      @query_type = key_state[:query_type]
      @logger.warn("SearchState.initialize: #{query_type}, #{@query_type}") if @logger
      @access_count = (key_state[:access_count] || 0) + 1
    else
      @title = nil
      @conditions = nil
      if (query_type == :images) and params[:obs]
        @conditions = "o.id = %s" % params[:obs]
      end
      @order = nil
      @source = nil
      @query_type = query_type
      @access_count = 0
    end
    if logger
      if session_state
        if session_state[key]
          for (key, value) in session_state[key]
            logger.warn("SearchState.initialize: key: #{key}, value: #{value}")
          end
        else
          logger.warn("SearchState.initialize: No search states matching #{key} found")
        end
      else
        logger.warn("SearchState.initialize: No search states found")
      end
    end
  end

  def setup?()
    @title && (@title != '')
  end
  
  def setup(title, conditions, order, source)
    @title = title
    conditions = nil if conditions == ''
    @conditions = conditions
    @order = order
    @source = source
  end
  
  def session_data()
    {
      :title => @title,
      :conditions => @conditions,
      :order => @order,
      :source => @source,
      :query_type => @query_type,
      :access_count => @access_count,
      :timestamp => @timestamp,
    }
  end
end
