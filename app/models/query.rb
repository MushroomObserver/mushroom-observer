#
#  = Query Model
#
################################################################################

class Query < AbstractQuery
  belongs_to :user

  # Parameters required for each flavor.
  self.required_params = {
    :advanced => {
      :name?     => :string,
      :location? => :string,
      :user?     => :string,
      :content?  => :string
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
      :outer       => Query,
    },
    :of_children => {
      :name => Name,
      :all? => :boolean,
    },
    :of_name => {
      :name          => Name,
      :synonyms?     => {:string => [:no, :all, :exclusive]},
      :nonconsensus? => {:string => [:no, :all, :exclusive]},
    },
    :of_parents => {
      :name => Name,
    },
    :pattern => {
      :pattern => :string,
    },
    :with_observations_at_location => {
      :location => Location,
    },
    :with_observations_at_where => {
      :location => :string,
    },
    :with_observations_by_user => {
      :user => User,
    },
    :with_observations_in_set => {
      :ids => [Observation],
      :old_title? => :string,
      :old_by?    => :string,
    },
    :with_observations_in_species_list => {
      :species_list => SpeciesList,
    },
    :with_observations_of_children => {
      :name => Name,
      :all? => :boolean,
    },
    :with_observations_of_name => {
      :name          => Name,
      :synonyms?     => {:string => [:no, :all, :exclusive]},
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
      :with_observations,                 # Images with observations, alphabetically.
      :with_observations_at_location,     # Images with observations at a defined location.
      :with_observations_at_where,        # Images with observations at an undefined 'where'.
      :with_observations_by_user,         # Images with observations by user.
      :with_observations_in_set,          # Images with observations in a given set.
      :with_observations_in_species_list, # Images with observations in a given species list.
      :with_observations_of_children,     # Images with observations of children a given name.
      :with_observations_of_name,         # Images with observations of a given name.
    ],
    :Location => [
      :advanced,              # Advanced search results.
      :all,                   # All locations, alphabetically.
      :by_author,             # Locations that list user as an author, alphabetically.
      :by_editor,             # Locations that list user as an editor, alphabetically.
      :by_rss_log,            # Locations with RSS logs, in RSS order.
      :in_set,                # Locations in a given set.
      :pattern,               # Locations matching a pattern, alphabetically.
      :with_observations,                 # Locations with observations, alphabetically.
      :with_observations_by_user,         # Locations with observations by user.
      :with_observations_in_set,          # Locations with observations in a given set.
      :with_observations_in_species_list, # Locations with observations in a given species list.
      :with_observations_of_children,     # Locations with observations of children of a given name.
      :with_observations_of_name,         # Locations with observations of a given name.
    ],
    :Name => [
      :advanced,              # Advanced search results.
      :all,                   # All names, alphabetically.
      :by_author,             # Names that list user as an author, alphabetically.
      :by_editor,             # Names that list user as an editor, alphabetically.
      :by_rss_log,            # Names with RSS logs, in RSS order.
      :in_set,                # Names in a given set.
      :of_children,           # Names of children of a name.
      :of_parents,            # Names of parents of a name.
      :pattern,               # Names matching a pattern, alphabetically.
      :with_authors,          # Names that have authors, alphabetically.
      :with_observations,                 # Names with observations, alphabetically.
      :with_observations_at_location,     # Names with observations at a defined location.
      :with_observations_at_where,        # Names with observations at an undefined 'where'.
      :with_observations_by_user,         # Names with observations by user.
      :with_observations_in_set,          # Names with observations in a given set.
      :with_observations_in_species_list, # Names with observations in a given species list.
    ],
    :Observation => [
      :advanced,              # Advanced search results.
      :all,                   # All observations, by date.
      :at_location,           # Observations at a location, by modified.
      :at_where,              # Observations at an undefined location, by modified.
      :by_rss_log,            # Observations with RSS log, in RSS order.
      :by_user,               # Observations created by user, by modified.
      :in_set,                # Observations in a given set.
      :in_species_list,       # Observations in a given species list, by modified.
      :of_children,           # Observations of children of a given name.
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
    :comments => {
      :location_descriptions => :object,
      :name_descriptions => :object,
      :observations  => :object,
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
    :location_descriptions => {
      :locations     => :location_id,
      :users         => :user_id,
    },
    :location_descriptions_admins => {
      :location_descriptions => :location_description_id,
      :user_groups   => :user_group_id,
    },
    :location_descriptions_authors => {
      :location_descriptions => :location_description_id,
      :users         => :user_id,
    },
    :location_descriptions_editors => {
      :location_descriptions => :location_description_id,
      :users         => :user_id,
    },
    :location_descriptions_readers => {
      :location_descriptions => :location_description_id,
      :user_groups   => :user_group_id,
    },
    :location_descriptions_writers => {
      :location_descriptions => :location_description_id,
      :user_groups   => :user_group_id,
    },
    :locations => {
      :licenses      => :license_id,
      :'location_descriptions.official' => :description_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
    },
    :name_descriptions => {
      :names         => :name_id,
      :users         => :user_id,
    },
    :name_descriptions_admins => {
      :name_descriptions => :name_description_id,
      :user_groups   => :user_group_id,
    },
    :name_descriptions_authors => {
      :name_descriptions => :name_description_id,
      :users         => :user_id,
    },
    :name_descriptions_editors => {
      :name_descriptions => :name_description_id,
      :users         => :user_id,
    },
    :name_descriptions_readers => {
      :name_descriptions => :name_description_id,
      :user_groups   => :user_group_id,
    },
    :name_descriptions_writers => {
      :name_descriptions => :name_description_id,
      :user_groups   => :user_group_id,
    },
    :names => {
      :licenses      => :license_id,
      :'name_descriptions.official' => :description_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
      :'users.reviewer' => :reviewer_id,
    },
    :namings => {
      :names         => :name_id,
      :observations  => :observation_id,
      :users         => :user_id,
    },
    :notifications => {
      :names         => :obj,
      :users         => :user_id,
    },
    :observations => {
      :locations     => :location_id,
      :names         => :name_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
      :'images.thumb_image' => :thumb_image_id,
    },
    :observations_species_lists => {
      :observations  => :observation_id,
      :species_lists => :species_list_id,
    },
    :projects => {
      :users         => :user_id,
      :user_groups   => :user_group_id,
      :'user_groups.admin_group' => :admin_group_id,
    },
    :rss_logs => {
      :locations     => :location_id,
      :names         => :name_id,
      :observations  => :observation_id,
      :species_lists => :species_list_id,
    },
    :species_lists => {
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
    },
    :user_groups_users => {
      :user_groups   => :user_group_id,
      :users         => :user_id,
    },
    :users => {
      :images        => :image_id,
      :licenses      => :license_id,
      :locations     => :location_id,
    },
    :votes => {
      :namings       => :naming_id,
      :observations  => :observation_id,
      :users         => :user_id,
    },
  }

  # This is the order in which we should list tables, numbers are lengths.
  # This makes absolutely no difference whatsoever in performance. (!!)
  self.table_order = [
    :licenses,                       # 3
    :projects,                       # 4
    :location_descriptions_editors,  # 11
    :notifications,                  # 57
    :species_lists,                  # 92
    :name_descriptions_authors,      # 578
    :location_descriptions,          # 808
    :location_descriptions_admins,   # 808
    :location_descriptions_authors,  # 808
    :location_descriptions_readers,  # 808
    :location_descriptions_writers,  # 808
    :locations,                      # 808
    :interests,                      # 1021
    :users,                          # 1907
    :user_groups,                    # 1917
    :user_groups_users,              # 4016
    :observations_species_lists,     # 12837
    :comments,                       # 17380
    :names,                          # 21186
    :name_descriptions,              # 21358
    :name_descriptions_admins,       # 21358
    :name_descriptions_readers,      # 21530
    :name_descriptions_writers,      # 21530
    :name_descriptions_editors,      # 22733
    :observations,                   # 32328
    :rss_logs,                       # 36229
    :namings,                        # 38528
    :votes,                          # 51773
    :images_observations,            # 73975
    :images,                         # 76154
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

  # Extra parameters allowed in every query by default.
  def extra_parameters

    # Every query can customize title.
    args = { :title? => [:string] }

    # All Name queries get to control inclusion of misspellings.  (The default
    # is to ignore misspellings.)
    if model_symbol == :Name
      args[:misspellings?] = {:string => [:okay, :no, :only]}
      args[:deprecated?]   = {:string => [:okay, :no, :only]}
    end

    return args
  end

  ##############################################################################
  #
  #  :section: Titles
  #
  ##############################################################################

  # Holds the title, as a localization with args.  The default is
  # <tt>:query_title_{model}_{flavor}</tt>, passing in +params+ as args.
  #
  #   self.title_args = {
  #     :tag => :app_advanced_search,
  #     :pattern => clean_pattern,
  #   }
  #
  attr_accessor :title_args

  # Put together a localized title for this query.  (Intended for use as title
  # of the results index page.)
  def title
    initialize_query if !initialized?
    if raw = title_args[:raw]
      raw
    else
      title_args[:tag].to_sym.t(title_args)
    end
  end

  ##############################################################################
  #
  #  :section: Coercion
  #
  ##############################################################################

  # Attempt to coerce a query for one model into a related query for another
  # model.  This is currently only defined for a very few specific cases.  I
  # have no idea how to generalize it.  Returns a new Query in rare successful
  # cases; returns +nil+ in all other cases.
  def coerce(new_model, just_test=false)
    old_model  = self.model_symbol
    old_flavor = self.flavor
    new_model  = new_model.to_s.to_sym

    # Going from list_rss_logs to showing observation, name, or species list.
    if (old_model  == :RssLog) and
       (old_flavor == :all) and
       (new_model.to_s.constantize.reflect_on_association(:rss_log) rescue false)
      just_test or begin
        self.class.lookup(new_model, :by_rss_log, params)
      end

    # Going from objects with observations to those observations themselves.
    elsif (new_model  == :Observation) and
          [:Image, :Location, :Name].include?(old_model) and
          old_flavor.to_s.match(/^with_observations/)
      just_test or begin
        if old_flavor == :with_observations
          new_flavor = :all
        else
          new_flavor = old_flavor.to_s.sub(/^with_observations_/,'').to_sym
        end
        params2 = params.dup
        if params2[:title]
          params2[:title] = "raw " + title
        elsif params2[:old_title]
          # This is passed through from previous coerce.
          params2[:title] = "raw " + params2[:old_title]
          params2.delete(:old_title)
        end
        if params2[:old_by]
          # This is passed through from previous coerce.
          params2[:by] = params2[:old_by]
          params2.delete(:old_by)
        elsif params2[:by]
          # Can't be sure old sort order will continue to work.
          params2.delete(:by)
        end
        self.class.lookup(new_model, new_flavor, params2)
      end

    # Going from observations to objects with those observations.
    elsif (old_model == :Observation) and
          [:Image, :Location, :Name].include?(new_model)
      just_test or begin
        if old_flavor == :all
          new_flavor = :with_observations
        else
          new_flavor = "with_observations_#{old_flavor}".to_sym
        end
        params2 = params.dup
        if params2[:title]
          # This can spiral out of control, but so be it.
          params2[:title] = "raw " + :query_title_with_observations_in_set.
            t(:observations => title, :type => :observaton)
        end
        if params2[:by]
          # Can't be sure old sort order will continue to work.
          params2.delete(:by)
        end
        if old_flavor == :in_set
          params2.delete(:title) if params2.has_key?(:title)
          self.class.lookup(new_model, :with_observations_in_set,
              params2.merge(:old_title => title, :old_by => params[:by]))
        elsif old_flavor == :advanced || old_flavor == :pattern
          params2.delete(:title) if params2.has_key?(:title)
          self.class.lookup(new_model, :with_observations_in_set,
              :ids => result_ids, :old_title => title, :old_by => params[:by])
        elsif (new_model == :Location) and
              (old_flavor == :at_location)
          self.class.lookup(new_model, :in_set,
                                     :ids => params2[:location])
        elsif (new_model == :Name) and
              (old_flavor == :of_name)
          # TODO -- need 'synonyms' flavor
          # params[:synonyms] == :all / :no / :exclusive
          # params[:misspellings] == :okay / :no / :only
          nil
        elsif allowed_model_flavors[new_model].include?(new_flavor)
          self.class.lookup(new_model, new_flavor, params2)
        end
      end

    # Let superclass handle anything else.
    else
      super
    end
  end

  ##############################################################################
  #
  #  :section: Queries
  #
  ##############################################################################

  # Give query a default title before passing off to standard initializer.
  def initialize_query
    self.title_args = params.merge(
      :tag  => "query_title_#{flavor}".to_sym,
      :type => model_string.underscore.to_sym
    )
    super
  end

  def extra_initialization
    # Give all Name queries control over inclusion of misspellings.
    if model_symbol == :Name
      case params[:misspellings] || :no
      when :no
        self.where << 'names.correct_spelling_id IS NULL'
      when :only
        self.where << 'names.correct_spelling_id IS NOT NULL'
      else
      end
    end

    # Allow all queries to customize title.
    if args = params[:title]
      for line in args
        raise "Invalid syntax in :title parameter: '#{line}'" if line !~ / /
        title_args[$`.to_sym] = $'
      end
    end
  end

  # Tell SQL how to sort results using the <tt>:by => :blah</tt> mechanism.
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
        "#{table}.when DESC"
      end
    when 'name'
      if model == Image
        self.join << {:images_observations => {:observations => :names}}
        self.group = 'images.id'
        'MIN(names.search_name) ASC, images.when DESC'
      elsif model == Observation
        self.join << :names
        'names.text_name ASC, names.author ASC, observations.when DESC'
      elsif model == Name
        'names.text_name ASC, names.author ASC'
      elsif model.column_names.include?('search_name')
        "#{table}.search_name ASC"
      elsif model.column_names.include?('name')
        "#{table}.name ASC"
      elsif model.column_names.include?('title')
        "#{table}.title ASC"
      end
    when 'title', 'login', 'summary'
      if model.column_names.include?(by)
        "#{table}.#{by} ASC"
      end
    when 'user'
      if model.column_names.include?('user_id')
        self.join << :users
        'IF(users.name = "" OR users.name IS NULL, users.login, users.name) ASC'
      end
    when 'rss_log'
      if model.column_names.include?('rss_log_id')
        self.join << :rss_logs
        'rss_logs.modified DESC'
      end
    end
  end

  # (These are used by :query_title_all_by for :all queries.)
  BY_TAGS = {
    :date  => :app_date,
    :name  => :name,
    :title => :app_object_title,
    :user  => :user,
  }

  # --------------------------------------------
  #  Queries that essentially have no filters.
  # --------------------------------------------

  def initialize_all
    if (by = params[:by]) and
       (by = BY_TAGS[by.to_sym])
      title_args[:tag]   = :query_title_all_by
      title_args[:order] = by.t
    end
  end

  def initialize_by_rss_log
    self.join << :rss_logs
    params[:by] ||= 'rss_log'
  end

  def initialize_with_authors
    self.join << {:'name_descriptions.official' => :name_descriptions_authors}
    params[:by] ||= 'name'
  end

  # ----------------------------
  #  Get user contributions.
  # ----------------------------

  def initialize_by_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    table = model.table_name
    if model.column_names.include?('user_id')
      self.where << "#{table}.user_id = '#{params[:user]}'"
    else
      raise "Can't figure out how to select #{model_string} by user_id!"
    end
    case model_symbol
    when :Observation
      params[:by] ||= 'modified'
    when :Image
      params[:by] ||= 'modified'
    when :SpeciesList
      params[:by] ||= 'title'
    when :Comment
      params[:by] ||= 'created'
    end
  end

  def initialize_for_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.join << :observations
    self.where << "observations.user_id = '#{params[:user]}'"
    params[:by] ||= 'created'
  end

  def initialize_by_author
    initialize_by_editor
  end

  def initialize_by_editor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    case model_symbol
    when :Name, :Location
      desc_table = "#{model_string}_descriptions.official".downcase.to_sym
      glue_table = "#{model_string}_descriptions_#{flavor}s".downcase.
                      sub('_by_', '_').to_sym
      self.join << {desc_table => glue_table}
      self.where << "#{glue_table}.user_id = '#{params[:user]}'"
      params[:by] ||= 'name'
    else
      raise "No editors or authors in #{model_string}!"
    end
  end

  # -----------------------------------
  #  Various subsets of Observations.
  # -----------------------------------

  def initialize_at_location
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    self.join << :names
    self.where   << "observations.location_id = '#{params[:location]}'"
    params[:by] ||= 'name'
  end

  def initialize_at_where
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    self.join << :names
    self.where   << "observations.where LIKE '%#{pattern}%'"
    params[:by] ||= 'name'
  end

  def initialize_in_species_list
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    self.join << :names
    self.join << :observations_species_lists
    self.where   << "observations_species_lists.species_list_id = '#{params[:species_list]}'"
    params[:by] ||= 'name'
  end

  # ----------------------------------
  #  Queryies dealing with synonyms.
  # ----------------------------------

  def initialize_of_name
    name = find_cached_parameter_instance(Name, :name)

    synonyms     = params[:synonyms]     || :no
    nonconsensus = params[:nonconsensus] || :no

    title_args[:tag] = :query_title_of_name
    title_args[:tag] = :query_title_of_name_synonym      if synonyms != :no
    title_args[:tag] = :query_title_of_name_nonconsensus if nonconsensus != :no
    title_args[:name] = name.display_name

    if synonyms == :no
      name_ids = [name.id] + name.misspelling_ids
    elsif synonyms == :all
      name_ids = name.synonym_ids
    elsif synonyms == :exclusive
      name_ids = name.synonym_ids - [name.id] - name.misspelling_ids
    else
      raise "Invalid synonym inclusion mode: '#{synonyms}'"
    end
    set = clean_id_set(name_ids)

    if nonconsensus == :no
      self.where << "observations.name_id IN (#{set})"
      self.where << "observations.vote_cache >= 0"
      self.order = "observations.vote_cache DESC, observations.when DESC"
    elsif nonconsensus == :all
      self.where << "observations.name_id IN (#{set}) AND " +
                    "observations.vote_cache >= 0 OR " +
                    "namings.name_id IN (#{set}) AND " +
                    "namings.vote_cache >= 0"
      self.order = "IF(observations.vote_cache > namings.vote_cache, " +
                   "observations.vote_cache, namings.vote_cache) DESC, " +
                   "observations.when DESC"
    elsif nonconsensus == :exclusive
      self.where << "namings.name_id IN (#{set})"
      self.where << "namings.vote_cache >= 0"
      self.where << "observations.name_id NOT IN (#{set})"
      self.order = "namings.vote_cache DESC, observations.when DESC"
    else
      raise "Invalid nonconsensus inclusion mode: '#{nonconsensus}'"
    end

    # Different join conditions for different models.
    if model_symbol == :Observation
      if nonconsensus != :no
        self.join << :namings
      end

    elsif model_symbol == :Location
      if nonconsensus != :no
        self.join << :observations
      else
        self.join << {:observations => :namings}
      end
      self.where << "observations.is_collection_location IS TRUE"

    elsif model_symbol == :Image
      if nonconsensus != :no
        self.join << {:images_observations => :observations}
      else
        self.join << {:images_observations => {:observations => :namings}}
      end
    end
  end

  # --------------------------------------------
  #  Queries dealing with taxonomic hierarchy.
  # --------------------------------------------

  def initialize_of_children
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    all = params[:all] || false
    params[:by] ||= 'name'

    # If we have to rely on classification strings, just let Name do it, and
    # create a pseudo-query based on ids returned by +name.children+.
    if all || name.above_genus?
      set = clean_id_set(name.children(all).map(&:id))
      self.where << "names.id IN (#{set})"

    # If at genus or below, we can deduce hierarchy purely by syntax.
    else
      self.where << "names.text_name LIKE '#{name.text_name} %'"
      if !all
        if name.rank == :Genus
          self.where << "names.text_name NOT LIKE '#{name.text_name} % %'"
        else
          self.where << "names.text_name NOT LIKE '#{name.text_name} % % %'"
        end
      end
    end

    # Add appropriate joins.
    if model_symbol == :Observation
      self.join << :names
    elsif model_symbol == :Image
      self.join << {:images_observations => {:observations => :names}}
    elsif model_symbol == :Location
      self.join << {:observations => :names}
    end
  end

  def initialize_of_parents
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    all = params[:all] || false
    set = clean_id_set(name.parents(all).map(&:id))
    self.where << "names.id IN (#{set})"
    params[:by] ||= 'name'
  end

  # ---------------------------------------------------------------------
  #  Coercable image/location/name queries based on observation-related
  #  conditions.
  # ---------------------------------------------------------------------

  def initialize_with_observations
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    params[:by] ||= 'name'
  end

  def initialize_with_observations_at_location
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    self.where << "observations.location_id = '#{params[:location]}'"
    self.where << 'observations.is_collection_location IS TRUE'
    params[:by] ||= 'name'
  end

  def initialize_with_observations_at_where
    location = params[:location]
    title_args[:where] = location
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    self.where << "observations.where LIKE '%#{clean_pattern(location)}%'"
    self.where << 'observations.is_collection_location IS TRUE'
    params[:by] ||= 'name'
  end

  def initialize_with_observations_by_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    self.where << "observations.user_id = '#{params[:user]}'"
    if model_symbol == :Location
      self.where << 'observations.is_collection_location IS TRUE'
    end
    params[:by] ||= 'name'
  end

  def initialize_with_observations_in_set
    title_args[:observations] = params[:old_title] ||
      :query_title_in_set.t(:type => :observation)
    set = clean_id_set(params[:ids])
    if model_symbol == :Image
      self.join << {:images_observations => :observations}
    else
      self.join << :observations
    end
    self.where << "observations.id IN (#{set})"
    if model_symbol == :Location
      self.where << 'observations.is_collection_location IS TRUE'
    end
    params[:by] ||= 'name'
  end

  def initialize_with_observations_in_species_list
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    if model_symbol == :Image
      self.join << {:images_observations => {:observations => :observations_species_lists}}
    else
      self.join << {:observations => :observations_species_lists}
    end
    self.where << "observations_species_lists.species_list_id = '#{params[:species_list]}'"
    if model_symbol == :Location
      self.where << 'observations.is_collection_location IS TRUE'
    end
    params[:by] ||= 'name'
  end

  def initialize_with_observations_of_children
    initialize_of_children
  end

  def initialize_with_observations_of_name
    initialize_of_name
    title_args[:tag] = title_args[:tag].to_s.sub('title', 'title_with_observations').to_sym
  end

  # ----------------------------
  #  Pattern search.
  # ----------------------------

  def initialize_pattern
    pattern = params[:pattern].to_s.strip_squeeze
    search = google_parse(pattern)

    case model_symbol

    when :Image
      self.join << {:images_observations => {:observations => :names}}
      ids = []
      # Search observations without location first.
      ids += google_execute(search, :where => 'observations.location_id IS NULL',
          :fields => [ 'observations.notes', 'observations.where',
                       'names.search_name', 'images.copyright_holder',
                       'images.notes' ])
      # Now search observations with location.
      ids += google_execute(search,
          :join => {:images_observations => {:observations => :locations}},
          :fields => [ 'observations.notes', 'names.search_name',
                       'images.copyright_holder', 'images.notes',
                       'locations.display_name', 'locations.search_name' ])
      # This is what we'd do to include comments.
      # ids += google_execute(search,
      #     :join => {:images_observations => {:observations => :comments}},
      #     :fields => [ 'observations.notes', 'names.search_name',
      #                  'images.copyright_holder', 'images.notes',
      #                  'comments.summary', 'comments.comment' ])

    when :Location
      note_fields = LocationDescription.all_note_fields.
                      map {|x| "location_descriptions.#{x}"}
      ids = google_execute(search, :join => :location_descriptions,
        :fields => [ 'locations.display_name', 'locations.search_name',
                     *note_fields ])

    when :Name
      note_fields = NameDescription.all_note_fields.
                      map {|x| "name_descriptions.#{x}"}
      ids = google_execute(search, :join => :name_descriptions,
        :fields => [ 'names.search_name', 'names.citation', *note_fields ])

    when :Observation
      self.join << :names
      ids = []
      # Search observations without location or comments.
      ids += google_execute(search, :where => 'observations.location_id IS NULL',
          :fields => [ 'observations.notes', 'observations.where',
                       'names.search_name' ])
      # Search observations with location.
      ids += google_execute(search, :join => :locations, :fields =>
          [ 'observations.notes', 'names.search_name', 'locations.display_name',
            'locations.search_name' ])
      # Search observations with comments.  This is not correct, but it's a
      # reasonable compromise.  Ideally, we'd like to allow different positive
      # assertions apply to different comments, but that would require N
      # queries for N positive assertions.  Yesyesyes, granted, subsequent
      # queries become very small, but...
      ids += google_execute(search, :join => :comments, :fields =>
          [ 'observations.notes', 'names.search_name', 'comments.summary',
            'comments.comment' ])

    else
      raise "Forgot to tell me how to build a :#{flavor} query for #{model}!"
    end

    # Convert this to an "in_set" query now that we have results.
    self.flavor    = :in_set
    params[:ids]   = ids.uniq[0,MAX_ARRAY]
    params[:title] = ["tag query_title_pattern", "pattern #{pattern}"]
    params[:by]  ||= 'name'
    params.delete(:pattern)
    self.save if self.id
    initialize_query
  end

  # ----------------------------
  #  Advanced search.
  # ----------------------------

  def initialize_advanced
    name     = params[:name].to_s.strip_squeeze
    user     = params[:user].to_s.strip_squeeze
    location = params[:location].to_s.strip_squeeze
    content  = params[:content].to_s.strip_squeeze

    if name + user + location + content == ''
      raise "You must specify at least one of the four conditions."

    # I was thinking about turning these into pattern searches.  But I think
    # that could be confusing.  Adding, say, a "user" condition to one of
    # these, the results would be totally different.
    # elsif (model_symbol == :Name) and (user + location + content == '')
    # elsif (model_symbol == :Image) and (user + location + name == '')
    # elsif (model_symbol == :Location) and (user + name + content == '')

    # Easy case: just searching on Name and User.
    elsif location + content == ''
      if name != ''
        clean = clean_pattern(name)
        self.where << "names.search_name LIKE '%#{clean}%'"
        case model_symbol
        when :Image       ; self.join << {:images_observations => {:observations => :names}}
        when :Location    ; self.join << {:observations => :names}
        when :Observation ; self.join << :names
        end
      end
      if user != ''
        clean = clean_pattern(user)
        self.where << "users.name LIKE '%#{clean}%' OR " +
                      "users.login LIKE '%#{clean}%'"
        case model_symbol
        when :Image       ; self.join << {:images_observations => {:observations => :users}}
        when :Location    ; self.join << {:observations => :users}
        when :Name        ; self.join << {:observations => :users}
        when :Observation ; self.join << :users
        end
      end
      params[:by] ||= 'name'

    # The other easy cases are the non-observation models: run the query for
    # observation first, then coerce into our type.
    elsif model_symbol != :Observation
      if !allowed_model_flavors[model_symbol].include?(:with_observations_in_set)
        raise "Forgot to tell me how to build a :#{with_observations_in_set} query for #{model}!"
      end
      subquery = self.class.lookup(:Observation, :advanced, params)
      self.flavor    = :with_observations_in_set
      params[:ids]   = subquery.result_ids.uniq[0,MAX_ARRAY]
      params[:title] = ["tag query_title_advanced"]
      params[:by]  ||= 'name'
      self.save if self.id
      initialize_query

    # Now we've reduced the problem to merely doing a hideously nasty query
    # for observations.  At least the joins are smaller this way.
    else
      ids = []

      if name != ''
        self.join << :names
        clean = clean_pattern(name)
        self.where << "names.search_name LIKE '%#{clean}%'"
      end

      if user != ''
        clean = clean_pattern(user)
        self.where << "users.name LIKE '%#{clean}%' OR " +
                      "users.login LIKE '%#{clean}%'"
        self.join << :users
      end

      if location != ''
        search = google_parse(location)
        ids += google_execute(search, :fields => [ 'observations.where' ],
            :where => 'observations.location_id IS NULL')
        ids += google_execute(search, :join => :locations,
            :fields => [ 'locations.display_name', 'locations.search_name' ])
      end

      if content != ''
        more_ids = []
        search = google_parse(content)
        more_ids += google_execute(search, :fields => [ 'observations.notes' ])
        more_ids += google_execute(search, :join => :comments,
            :fields => [ 'observations.notes', 'comments.summary', 'comments.comment' ])

        if location != ''
          ids = intersect_id_sets(ids, more_ids)
        else
          ids = more_ids
        end
      end

      self.flavor    = :in_set
      params[:ids]   = ids.uniq[0,MAX_ARRAY]
      params[:title] = ["tag query_title_advanced"]
      params[:by]  ||= 'name'
      self.save if self.id
      initialize_query
    end
  end

  # Find intersection of a bunch of sets.
  def intersect_id_sets(*sets)
    if sets.length > 1
      counter = {}
      for id in sets.flatten
        counter[id] ||= 0
        counter[id] += 1
      end
      n = sets.length
      counter.keys.select {|id| counter[id] == n}
    else
      sets.first
    end
  end

  # ----------------------------
  #  Nested queries.
  # ----------------------------

  def initialize_inside_observation
    obs = find_cached_parameter_instance(Observation, :observation)
    title_args[:observation] = obs.unique_format_name

    ids = []
    ids << obs.thumb_image_id if obs.thumb_image_id
    ids += obs.image_ids - [obs.thumb_image_id]
    initialize_in_set(ids)

    self.outer_id = params[:outer]

    # Tell it to skip observations with no images!
    self.tweak_outer_query = lambda do |outer|
      (outer.params[:join] ||= []) << :images_observations
    end
  end
end
