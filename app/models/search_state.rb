#
#  = Search State Model
#
#  See docs at top of SequenceState class for usage, valid query_types, and
#  other information.  These two classes are meant to work cosely together.
#
#  == Query Types
#
#  species_list_observations:: Observations in a SpeciesList.
#  name_observations::         Observations whose consensus is a given Name or a misspelling thereof.
#  synonym_observations::      Observations whose consensus Name is a Synonym of a given Name.
#  other_observations::        Observations with a non-consensus Name that's a Synonym of a given Name.
#  observations::              Observations at a given Location.
#  images::                    Images for a given Observation or Name.
#  rss_logs::                  Observations as found in RssLogs.
#  advanced_observations::     ???
#  advanced_images::           ???
#  advanced_names::            ???
#  adv_obs_comments::          Observations from advanced search.
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  query_type::         Query type, e.g. :image.
#  title::              Title to use in view.
#  conditions::         SQL conditions.
#  order::              SQL order.
#  source::             Goes in session[:checklist_source]
#  access_count::       Number of times used.
#  timestamp::          Last time used.
#
#  == Instance Variables
#
#  @cache::             Simple list of object ids (integers).
#  @start_index::       Index of first object in cache.
#  @count::             Number of objects in cache.  (Same as @cache.length.)
#  @has_full_cache::    Does cache contain entire query?
#  @logger::            Optional logger.
#
#  == Class Methods
#
#  lookup::             Look up a search state, creating one if necessary.
#  cleanup::            Clean out old states.
#  all_query_types::    List of allowed query_type values (symbols).
#
#  == Instance Methods
#
#  setup::              Set the standard options.
#  setup?::             Has this state been set up yet?
#  query::              Create SQL query given options set in setup.
#  log::                Add debug message to server log (given in lookup).
#  text_name::          Alias for +query_type+ for debugging.
#
#  == Callbacks
#
#  None.
#
################################################################################

class SearchState < ActiveRecord::MO

  # Set of allowed query_types (used to define enum type in database).
  def self.all_query_types
    [
      :adv_obs_comments,
      :advanced_images,
      :advanced_names,
      :advanced_observations,
      :images,
      :name_observations,
      :observations,
      :other_observations,
      :rss_logs,
      :species_list_observations,
      :synonym_observations,
    ]
  end

  # Returns +query_type+ for debugging.
  def text_name
    query_type.to_s
  end

  # Add debug message to system log.  (Logger provided to +lookup+.)
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

  # Has this state been set up yet?  (Just checks if +title+ has been set.)
  def setup?
    self.title.to_s != ''
  end

  # Provide query parameters to new search state.
  def setup(title, conditions=nil, order=nil, source=:nothing)
    self.title      = title
    self.conditions = conditions == '' ? nil : conditions
    self.order      = order
    self.source     = source
  end

  ##############################################################################
  #
  #  :section: Constructors
  #
  ##############################################################################

  # Look up a search state.  Looks for the one referred to by
  # params[:search_seq], or creates one if not found (e.g. culled by garbage
  # collection).
  #
  # Internal note: this method must be able to create and essentially setup a
  # fully-working query in case this is being called implicitly by
  # SequenceState.lookup, since in that case search_state.setup cannot be
  # called.  Thus there is a case (and presumably will be more later) in which
  # other magic +params+ are used (params[:obs] in :image_search) to tweak the
  # conditions.
  #
  def self.lookup(params, query_type=:rss_logs, logger=nil)
    # Look up existing state.
    if (id = params[:search_seq]) and (state = self.safe_find(id))
      state.timestamp = Time.now
      state.access_count += 1

    else
      # Do garbage collection.
      cleanup

      # Initialize new state.
      state = self.new(
        :title        => nil,
        :order        => nil,
        :source       => nil,
        :query_type   => query_type,
        :timestamp    => Time.now,
        :access_count => 0,
        :conditions   => nil
      )

      # Make special exception for :images query.
      if (query_type == :images) and params[:obs]
        state.conditions = "observations.id = %d" % params[:obs].to_i
      end
    end

    @logger = logger
    return state
  end

  ##############################################################################
  #
  #  :section: Build Query
  #
  ##############################################################################

  # Build SQL statement for this search.
  def query
    result = nil
    order2 = order
    conditions2 = conditions
    case self.query_type

    # Observations in a SpeciesList.
    when :species_list_observations
      result = %(
        SELECT observations.id, names.search_name
        FROM names, observations, observations_species_lists, species_lists
        WHERE names.id = observations.name_id
          AND observations_species_lists.observation_id = observations.id
          AND observations_species_lists.species_list_id = species_lists.id
      )

    # Observations whose consensus is a given Name or a misspelling thereof.
    when :name_observations
      result = %(
        SELECT observations.id, observations.when, observations.thumb_image_id,
          observations.where, observations.location_id, users.name, users.login,
          observations.user_id, names.observation_name, observations.vote_cache
        FROM observations, users, names
        WHERE names.id = observations.name_id
          AND users.id = observations.user_id
      )

    # Observations whose consensus Name is a Synonym of a given Name (but
    # is NOT actually that Name or a misspelling of that Name).
    when :synonym_observations
      result = %(
        SELECT observations.id, observations.when, observations.thumb_image_id,
          observations.where, observations.location_id, users.name, users.login,
          observations.user_id, names.observation_name, observations.vote_cache
        FROM observations, users, names
        WHERE names.id = observations.name_id
          AND users.id = observations.user_id
          AND !(observations.vote_cache < 0)
      )

    # Observations with a non-consensus Name that's a Synonym of a given Name.
    when :other_observations
      # Matches on non-consensus namings, any vote.
      result = %(
        SELECT observations.id, observations.when, observations.thumb_image_id,
          observations.where, observations.location_id, users.name, users.login,
          observations.user_id, names.observation_name, namings.vote_cache
        FROM observations, users, names, namings
        WHERE namings.observation_id = observations.id
          AND names.id = observations.name_id
          AND users.id = observations.user_id
          AND observations.name_id != namings.name_id
          AND !(namings.vote_cache < 0)
      )

    # Observations at a given Location.
    when :observations
      result = %(
        SELECT observations.*, names.search_name
        FROM names, observations
        LEFT OUTER JOIN locations ON observations.location_id = locations.id
        WHERE observations.name_id = names.id
      )

    # ???
    when :advanced_observations, :advanced_images, :advanced_names
      result = conditions
      conditions2 = nil

    # Observations from advanced search.
    when :adv_obs_comments
      result = %(
        SELECT observations.*, names.search_name
        FROM observations, names, locations, users, comments
        WHERE names.id = observations.name_id
          AND locations.id = observations.location_id
          AND users.id = observations.user_id
          AND comments.object_id = observations.id
          AND comments.object_type = 'Observation'
      )

    # Images for a given Observation or Name.
    when :images
      result = %(
        SELECT DISTINCT images.*
        FROM images, images_observations, observations, names
        WHERE images.id = images_observations.image_id
          AND observations.id = images_observations.observation_id
          AND names.id = observations.name_id
      )
      order2 = order || 'images.id'

    # Observations as found in RssLogs.
    when :rss_logs
      result = %(
        SELECT observation_id AS id, modified
        FROM rss_logs
        WHERE observation_id IS NOT NULL
          AND modified IS NOT NULL
      )

    else
      raise(ArgumentError, "Missing or invalid query type: \"#{self.query_type}\"")
    end

    # Tack on additional conditions and/or ordering.
    result += " AND (#{conditions2})" if conditions2
    result += " ORDER BY #{order2 || 'modified DESC'}"

    return result
  end

  ##############################################################################
  #
  #  :section: Garbage Collection
  #
  ##############################################################################

  # Only keep unused states around for an hour, and used states for a day.
  # This goes through the whole lot and destroys old ones.
  def self.cleanup
    self.connection.delete %(
      DELETE FROM search_states
      WHERE access_count = 0 AND timestamp < DATE_SUB(NOW(), INTERVAL 1 HOUR) OR
            access_count > 0 AND timestamp < DATE_SUB(NOW(), INTERVAL 1 DAY)
    )
    self.connection.delete %(
      DELETE FROM sequence_states
      WHERE access_count = 0 AND timestamp < DATE_SUB(NOW(), INTERVAL 1 HOUR) OR
            access_count > 0 AND timestamp < DATE_SUB(NOW(), INTERVAL 1 DAY)
    )
  end
end
