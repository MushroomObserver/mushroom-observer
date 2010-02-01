#
#  = Query Model
#
################################################################################

class Query < AbstractQuery
  belongs_to :user
  belongs_to :outer, :class_name => 'Query', :foreign_key => 'outer_id'

  # Parameters required for each flavor.
  self.required_params = {
    :advanced => {
      :name? => :string,
      :location? => :string,
      :user? => :string,
      :content? => :string
    },
    :at_location => {
      :location => Location,
    },
    :at_where => {
      :location => :string,
    },
    :by_author => {
      :user => User,
    },
    :by_editor => {
      :user => User,
    },
    :by_user => {
      :user => User,
    },
    :children => {
      :name => Name,
      :all? => :boolean,
    },
    :for_user => {
      :user => User,
    },
    :in_set => {
      :ids => [AbstractModel],
    },
    :in_species_list => {
      :species_list => SpeciesList,
    },
    :inside_observation => {
      :observation => Observation,
      :outer => Query,
    },
    :of_name => {
      :name => Name,
      :synonyms? => {:string => [:no, :all, :exclusive]},
      :nonconsensus? => {:string => [:no, :all, :exclusive]},
    },
    :parents => {
      :name => Name,
    },
    :pattern => {
      :pattern => :string,
    },
    :with_observations_of_name => {
      :name => Name,
      :synonyms? => {:string => [:no, :all, :exclusive]},
      :nonconsensus? => {:string => [:no, :all, :exclusive]},
    },
  }

  # Allowed flavors for each model.
  self.allowed_model_flavors = {
    :Comment => [
      :all,                   # All comments, by created.
      :by_user,               # Comments created by user, by modified.
      :in_set,                # Comments in a given set.
      :for_user,              # Comments sent to used, by modified.
    ],
    :Image => [
      :advanced,              # Advanced search results.
      :all,                   # All images, by created.
      :by_user,               # Images created by user, by modified.
      :in_set,                # Images in a given set.
      :inside_observation,    # Images belonging to outer observation query.
      :pattern,               # Images matching a pattern, by ???.
    ],
    :Location => [
      :advanced,              # Advanced search results.
      :all,                   # All locations, alphabetically.
      :by_author,             # Locations that list user as an author, alphabetically.
      :by_editor,             # Locations that list user as an editor, alphabetically.
      :in_set,                # Locations in a given set.
      :pattern,               # Locations matching a pattern, alphabetically.
      :with_observations_of_name, # Locations with observation of a given name.
    ],
    :Name => [
      :advanced,              # Advanced search results.
      :all,                   # All names, alphabetically.
      :by_author,             # Names that list user as an author, alphabetically.
      :by_editor,             # Names that list user as an editor, alphabetically.
      :by_rss_log,            # Names with RSS logs, in RSS order.
      :children,              # Children of a name.
      :in_set,                # Names in a given set.
      :parents,               # Parents of a name.
      :pattern,               # Names matching a pattern, alphabetically.
      :with_authors,          # Names that have authors, alphabetically.
      :with_observations,     # Names that have observations, alphabetically.
    ],
    :Observation => [
      :advanced,              # Advanced search results.
      :all,                   # All observations, by date.
      :at_location,           # Observations at a location, by modified.
      :at_where,              # Observations at an undefined location, by modified.
      :by_rss_log,            # Observations with RSS log, in RSS order.
      :by_user,               # Observations created by user, by modified.
      :in_set,                # Observations in a given set.
      :in_species_list,       # Observations in a species list, by modified.
      :of_name,               # Observations with a given name.
      :pattern,               # Observations matching a pattern, by name.
    ],
    :Project => [
      :all,                   # All projects, by title.
      :in_set,                # Projects in a given set.
    ],
    :RssLog => [
      :all,                   # All RSS logs, most recent activity first.
      :in_set,                # RSS logs in a given set.
    ],
    :SpeciesList => [
      :all,                   # All species lists, alphabetically.
      :by_rss_log,            # Species lists with RSS log, in RSS order
      :by_user,               # Species lists created by user, alphabetically.
      :in_set,                # Species lists in a given set.
    ],
    :User => [
      :all,                   # All users, by name.
      :in_set,                # Users in a given set.
    ],
  }

  # Map each pair of tables to the foreign key name.
  self.join_conditions = {
    :authors_locations => {
      :locations     => :location_id,
      :users         => :user_id,
    },
    :authors_names => {
      :names         => :name_id,
      :users         => :user_id,
    },
    :comments => {
      :users         => :user_id,
      :observations  => :object,
    },
    :editors_locations => {
      :locations     => :location_id,
      :users         => :user_id,
    },
    :editors_names => {
      :names         => :name_id,
      :users         => :user_id,
    },
    :images => {
      :users         => :user_id,
      :licenses      => :license_id,
      :'users.reviewers' => :reviewer_id,
    },
    :images_observations => {
      :images        => :image_id,
      :observations  => :observation_id,
    },
    :interests => {
      :locations     => :object,
      :names         => :object_id,
      :observations  => :object_id,
      :users         => :user_id,
    },
    :locations => {
      :users         => :user_id,
      :licenses      => :license_id,
    },
    :names => {
      :users         => :user_id,
      :'users.reviewer' => :reviewer_id,
      :licenses      => :license_id,
    },
    :naming_reasons => {
      :namings       => :naming_id,
    },
    :namings => {
      :observations  => :observation_id,
      :names         => :name_id,
      :users         => :user_id,
    },
    :notifications => {
      :users         => :user_id,
      :names         => :obj,
    },
    :observations => {
      :users         => :user_id,
      :'images.thumb_image' => :thumb_image_id,
      :names         => :name_id,
      :locations     => :location_id,
    },
    :observations_species_lists => {
      :observations  => :observation_id,
      :species_lists => :species_list_id,
    },
    :projects => {
      :users         => :user_id,
      :'user_groups.admin_group' => :admin_group_id,
      :user_groups   => :user_group_id,
    },
    :rss_logs => {
      :observations  => :observation_id,
      :species_lists => :species_list_id,
      :names         => :name_id,
    },
    :species_lists => {
      :users         => :user_id,
    },
    :user_groups_users => {
      :users         => :user_id,
      :user_groups   => :user_group_id,
    },
    :users => {
      :licenses      => :license_id,
      :locations     => :location_id,
      :images        => :image_id,
    },
    :votes => {
      :namings       => :naming_id,
      :users         => :user_id,
      :observations  => :observation_id,
    },
  }

  # This is the order in which we should list tables, numbers are lengths.
  self.table_order = [
    :licenses,                     # 3
    :projects,                     # 4
    :editors_locations,            # 8
    :user_groups,                  # 9
    :notifications,                # 57
    :species_lists,                # 90
    :user_groups_users,            # 202
    :authors_names,                # 405
    :authors_locations,            # 779
    :locations,                    # 779
    :interests,                    # 1033
    :users,                        # 1857
    :observations_species_lists,   # 12428
    :comments,                     # 16868
    :names,                        # 21062
    :editors_names,                # 23801
    :observations,                 # 31339
    :naming_reasons,               # 32886
    :rss_logs,                     # 35095
    :namings,                      # 37251
    :votes,                        # 49876
    :images_observations,          # 71686
    :images,                       # 73660
  ]

  # Return the default order for this query.
  def default_order
    case model_symbol
    when :Comment     ; 'created'
    when :Image       ; 'created'
    when :Location    ; 'name'
    when :Name        ; 'name'
    when :Observation ; 'date'
    when :Project     ; 'title'
    when :RssLog      ; 'modified'
    when :SpeciesList ; 'title'
    when :User        ; 'name'
    end
  end

  # All Name queries get to control inclusion of misspellings.  (The default is
  # to ignore misspellings.) 
  def extra_parameters
    if model_symbol == :Name
      {:misspellings? => {:string => [:yes, :no, :only]}}
    end
  end

  # Attempt to coerce a query for one model into a related query for another
  # model.  This is currently only defined for a very few specific cases.  I
  # have no idea how to generalize it.  Returns a new Query in rare successful
  # cases; returns +nil+ in all other cases.
  def coerce(new_model)
    result = nil
    new_model = new_model.to_s.to_sym

    # Going from list_rss_logs to showing observation, name, or species list.
    if model  == :RssLog and
       flavor == :all    and
       (result = self.class.lookup(new_model, :by_rss_log, params) rescue nil)

    # Going from mapping the observations of a name to showing the observations.
    elsif model     == :Location    and
          new_model == :Observation and
          flavor    == :with_observations_of_name and
          (result = self.class.lookup(new_model, :of_name, params) rescue nil)
    else
      result = super
    end
    return result
  end

  ##############################################################################
  #
  #  :section: Queries
  #
  ##############################################################################

  def initialize_extra
    # Give all Name queries control over inclusion of misspellings.
    if model_symbol == :Name
      case params[:misspellings] || :no
      when :yes
        # No condition needed.
      when :no
        self.where << 'names.correct_spelling_id IS NULL'
      when :only
        self.where << 'names.correct_spelling_id IS NOT NULL'
      else
      end
    end
  end

  def initialize_order(by)
    table = model.table_name
    case by
    when 'modified', 'created', 'last_login'
      if model.column_names.include?(by)
        "#{table}.#{by} DESC"
      end
    when 'date'
      if model.column_names.include?('date')
        "#{table}.date DESC"
      elsif model.column_names.include?('when')
        "#{table}.`when` DESC"
      end
    when 'name'
      if model == Observation
        self.include << :names
        "names.search_name ASC"
      elsif model.column_names.include?('search_name')
        "#{table}.search_name ASC"
      elsif model.column_names.include?('name')
        "#{table}.name ASC"
      end
    when 'title', 'login'
      if model.column_names.include?(by)
        "#{table}.#{by} ASC"
      end
    end
  end

  # --------------------------------------------
  #  Queries that essentially have no filters.
  # --------------------------------------------

  def initialize_all
  end

  def initialize_by_rss_log
    self.include << :rss_logs
    self.order = "rss_logs.modified DESC"
  end

  def initialize_with_authors
    self.include << :authors_names
    self.order = 'names.search_name ASC'
  end

  def initialize_with_observations
    self.include << :observations
    self.order = 'names.search_name ASC'
  end

  # ----------------------------
  #  Get user contributions.
  # ----------------------------

  def initialize_by_user
    table = model.table_name
    if model.column_names.include?('user_id')
      self.where << "#{table}.user_id = '#{params[:user]}'"
    else
      raise "Can't figure out how to select #{model_string} by user_id!"
    end
    case model_symbol
    when :Observation
      self.order = "#{table}.modified DESC"
    when :Image
      self.order = "#{table}.modified DESC"
    when :SpeciesList
      self.order = "#{table}.`when` DESC"
    when :Comment
      self.order = "#{table}.created DESC"
    end
  end

  def initialize_for_user
    self.include << :observations
    self.where << "observations.user_id = '#{params[:user]}'"
    self.order = 'comments.created DESC'
  end

  def initialize_by_author
    initialize_by_editor
  end

  def initialize_by_editor
    case model_symbol
    when :Name, :Location
      glue_table = "#{flavor}s_#{model_string}s".downcase
      glue_table = glue_table[3..-1]
      self.include << glue_table.to_sym
      self.where << "#{glue_table}.user_id = '#{params[:user]}'"
      if model_symbol == :Name
        self.order = "names.search_name ASC"
      else
        self.order = "locations.search_name ASC"
      end
    else
      raise "No editors or authors in #{model_string}!"
    end
  end

  # -----------------------------------
  #  Various subsets of Observations.
  # -----------------------------------

  def initialize_at_location
    self.include << :names
    self.where   << "observations.location_id = '#{params[:location]}'"
    self.order   =  'names.search_name ASC, observations.`when` DESC'
  end

  def initialize_at_where
    pattern = "%#{params[:location].gsub(/[*']/,"%")}%"
    self.include << :names
    self.where   << "observations.where LIKE '#{pattern}'"
    self.order   =  'names.search_name ASC, observations.`when` DESC'
  end

  def initialize_in_species_list
    self.include << :names
    self.include << :observations_species_lists
    self.where   << "observations_species_lists.species_list_id = '#{params[:species_list_id]}'"
    self.order   =  'names.search_name ASC, observations.`when` DESC'
  end

  # ----------------------------------
  #  Queryies dealing with synonyms.
  # ----------------------------------

  def initialize_with_observations_of_name
    initialize_of_name
  end

  def initialize_of_name
    name = Name.find(params[:name])

    synonyms     = params[:synonyms]     || :no
    nonconsensus = params[:nonconsensus] || :no

    if synonyms == :no
      name_ids = [name.id] + name.misspelling_ids
    elsif synonyms == :all
      name_ids = name.synonym_ids
    elsif synonyms == :exclusive
      name_ids = name.synonym_ids - [name.id] - name.misspelling_ids
    else
      raise "Invalid synonym inclusion mode: '#{synonyms}'"
    end
    name_ids = name_ids.join(',')
    name_ids = '0' if name_ids.to_s == ''

    if nonconsensus == :no
      self.where << "observations.name_id IN (#{name_ids})"
      self.where << "observations.vote_cache >= 0"
      self.order = "observations.vote_cache DESC, observations.`when` DESC"
    elsif nonconsensus == :all
      self.where << "observations.name_id IN (#{name_ids}) AND " +
                    "observations.vote_cache >= 0 OR " +
                    "namings.name_id IN (#{name_ids}) AND " +
                    "namings.vote_cache >= 0"
      self.order = "MAX(observations.vote_cache, namings.vote_cache) DESC, observations.`when` DESC"
    elsif nonconsensus == :exclusive
      self.where << "namings.name_id IN (#{name_ids})"
      self.where << "namings.vote_cache >= 0"
      self.where << "observations.name_id NOT IN (#{name_ids})"
      self.order = "namings.vote_cache DESC, observations.`when` DESC"
    else
      raise "Invalid nonconsensus inclusion mode: '#{nonconsensus}'"
    end

    if nonconsensus != :no
      if model_symbol == :Observation
        self.include << :namings
      elsif model_symbol == :Location
        self.include << {:observations => :namings}
        self.where << "observations.is_collection_location IS TRUE"
      end
    elsif model_symbol == :Location
      self.include << :observations
    end
  end

  # --------------------------------------------
  #  Queries dealing with taxonomic hierarchy.
  # --------------------------------------------

  def initialize_children
    name = Name.find(params[:name])
    all = params[:all] || false
    name_ids = name.children(all).map(&:id).map(&:to_s).join(',')
    name_ids = 0 if name_ids == ''
    self.where << "names.id IN (#{name_ids})"
    self.order = "names.search_name ASC"
  end

  def initialize_parents
    name = Name.find(params[:name])
    name_ids = name.parents(all).map(&:id).map(&:to_s).join(',')
    name_ids = 0 if name_ids == ''
    self.where << "names.id IN (#{name_ids})"
    self.order = "names.search_name ASC"
  end

  # ----------------------------
  #  Advanced queries.
  # ----------------------------

  def initialize_pattern
    pattern = params[:pattern].to_s.strip_squeeze
    case model_symbol

    when :Observation
      self.include += [:names, :locations, :comments]
      soft = soft_google_search(pattern, 'names.search_name',
                                'observations.where', 'locations.search_name')
      full = full_google_search(pattern, 'observations.notes',
                                'comments.summary', 'comments.comment')
      self.where << "(#{soft} OR #{full})"
      self.order  = 'names.search_name ASC, observations.`when` DESC'

    when :Image
      self.include << {:images_observations => {:observations => :names}}
      soft = soft_google_search(pattern, 'names.search_name',
                                'images.copyright_holder')
      full = full_google_search(pattern, 'images.notes')
      self.where << "(#{soft} OR #{full})"
      self.order  = "names.search_name ASC, images.`when` DESC"

    when :Name
      soft = soft_google_search(pattern, 'names.search_name')
      full = full_google_search(pattern, 'names.citation',
                                *(Name.all_note_fields.map {|x| "names.#{x}"}))
      self.where << "(#{soft} OR #{full})"
      self.order = "names.search_name ASC"

    when :Location
      self.where += full_google_search(pattern, 'locations.search_name',
                                'locations.display_name', 'locations.notes')
      self.order = "locations.display_name ASC"

    else
      raise "Forgot to tell me how to build a :#{flavor} query for #{model}!"
    end
  end

  def initialize_advanced
    if (name = params[:name].to_s.strip_squeeze) != ''
      self.where += soft_google_search(name, 'names.search_name')
    end
    if (location = params[:location].to_s.strip_squeeze) != ''
      self.where += soft_google_search(location, 'locations.display_name',
                                       'locations.search_name')
    end
    if (user = params[:user].to_s.strip_squeeze) != ''
      self.where += soft_google_search(user, 'users.login', 'users.name')
    end
    if (content  = params[:content].to_s.strip_squeeze) != ''
      self.where += full_google_search(content, 'observations.notes',
                                       'comments.summary', 'comments.comment')
    end

    case model_symbol
    when :Image
      self.include << {:images_observations => {:observations => :names}}     if name
      self.include << {:images_observations => {:observations => :locations}} if location
      self.include << {:images_observations => {:observations => :users}}     if user
      self.include << {:images_observations => {:observations => :comments}}  if content
    when :Location
      self.include << {:observations => :names}     if name
      self.include << {:observations => :users}     if user
      self.include << {:observations => :comments}  if content
    when :Name
      self.include << {:observations => :locations} if location
      self.include << {:observations => :users}     if user
      self.include << {:observations => :comments}  if content
    when :Observation
      self.include << :names     if name
      self.include << :locations if location
      self.include << :users     if user
      self.include << :comments  if content
    else
      raise "Forgot to tell me how to build a :#{flavor} query for #{model}!"
    end
  end

  # ----------------------------
  #  Nested queries.
  # ----------------------------

  def initialize_inside_observation
    self.include << :images_observations
    self.where << "images_observations.observation_id = '#{params[:observation]}'"
    self.order = 'images.created ASC'
    self.outer_id = params[:outer]
  end

  def outer_tweak(outer)
    case [model_symbol, flavor]
    when [:Image, :inside_observation]
      (outer.params[:include] ||= []) << :images_observations
    end
  end

  def outer_this_id
    case [model_symbol, flavor]
    when [:Image, :inside_observation]
      params[:observation]
    end
  end

  def outer_setup(new_outer, new_params)
    case [model_symbol, flavor]
    when [:Image, :inside_observation]
      new_params[:observation] = new_outer.this_id
    end
  end
end
