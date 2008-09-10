#
#  See docs at top of SequenceState class for usage, valid query_types, and
#  other information.  These two classes are meant to work cosely together.
#
#  Attributes in database:
#    query_type          Query type, e.g. :image.
#    title               Title to use in view.
#    conditions          SQL conditions.
#    order               SQL order.
#    source              Goes in session[:checklist_source]
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
#    SearchState.lookup(params, query_type, logger)
#                            Look up a search state, creating one if necessary.
#    state.setup(title, conditions, order, source)
#                            Set the standard options.
#    state.setup?            Has this state been set up yet?
#                              (just checks if title has been set)
#    state.query             Create SQL query given options set in setup.
#    state.log(message)      Add debug message to server log (given in lookup).
#    SearchState.cleanup     Clean out old states.
#    SearchState.all_query_types
#                            List of allowed query_type values (symbols).
#
################################################################################

class SearchState < ActiveRecord::Base

  # Set of allowed query_types (used to define enum type in database).
  def self.all_query_types
    [
      :species_list_observations,
      :name_observations,
      :synonym_observations,
      :other_observations,
      :observations,
      :images,
      :rss_logs
    ]
  end

  # Look up a search state.  Looks for the one referred to by
  # params[:search_seq], or creates one if not found (e.g. culled by garbage
  # collection).
  #
  # Internal note: this method must be able to create and essentially setup
  # a fully-working query in case this is being called implicitly by
  # SequenceState.lookup, since in that case search_state.setup cannot be
  # called.  Thus there is a case (and presumably will be more later) in which
  # other magic +params+ are used (params[:obs] in :image_search) to tweak the
  # conditions.
  def self.lookup(params, query_type=:rss_logs, logger=nil)
    # Look up existing state.
    if (id = params[:search_seq]) and (state = self.safe_find(id))
      state.timestamp = Time.now
      state.access_count += 1
    # Create new state.
    else
      self.cleanup
      state = self.new
      state.title = nil
      if query_type == :images
        raise ArgumentError, "Image search missing observation ID." \
          if !params[:obs]
        state.conditions = "o.id = %d" % params[:obs].to_i
      else
        state.conditions = nil
      end
      state.order = nil
      state.source = nil
      state.query_type = query_type
      state.timestamp = Time.now
      state.access_count = 0
    end
    @logger = logger
    return state
  end

  # Lookup state with given ID, returning nil if it no longer exists.
  def self.safe_find(id)
    begin
      self.find(id)
    rescue ActiveRecord::RecordNotFound
      nil
    end
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

  # Has this state been set up yet?  (just checks if +title+ has been set)
  def setup?()
    self.title && (self.title != '')
  end

  # Provide query parameters to new search state.
  def setup(title, conditions, order, source)
    self.title = title
    conditions = nil if conditions == ''
    self.conditions = conditions
    self.order = order
    self.source = source
  end

  # Build SQL statement for this search.
  def query()
    result = nil
    order = self.order
    case self.query_type
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
    when :rss_logs
      result = "select observation_id as id, modified from rss_logs where observation_id is not null and " +
               "modified is not null"
    else
      raise(ArgumentError, "Missing or invalid query type: \"#{self.query_type}\"")
    end
    order = order || "modified desc"
    result += " and (#{self.conditions})" if self.conditions
    result + " order by #{order}"
  end

  # Only keep unused states around for an hour, and used states for a day.
  # This goes through the whole lot, and destroys old ones.
  def self.cleanup
    self.connection.delete %(
      DELETE FROM search_states
      WHERE timestamp < DATE_SUB(NOW(), INTERVAL 1 HOUR) AND
            (timestamp < DATE_SUB(NOW(), INTERVAL 1 DAY) OR access_count = 0)
    )
    self.connection.delete %(
      DELETE FROM sequence_states
      WHERE timestamp < DATE_SUB(NOW(), INTERVAL 1 HOUR) AND
            (timestamp < DATE_SUB(NOW(), INTERVAL 1 DAY) OR access_count = 0)
    )
  end
end
