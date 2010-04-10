#
#  = Query Model
#
################################################################################

class Query < AbstractQuery
  belongs_to :user

  # Parameters allowed in every query.
  self.global_params = {
    # Allow every query to customize its title.
    :title? => [:string],
  }

  # Parameters allowed in every query for a given model.
  self.model_params = {
    :Comment => {
      :created?     => [:time],
      :modified?    => [:time],
      :users?       => [User],
      :types?       => :string,
      :summary_has? => :string,
      :content_has? => :string,
    },
    :Image => {
      :created?         => [:time],
      :modified?        => [:time],
      :date?            => [:date],
      :users?           => [User],
      :names?           => [Name],
      :synonym_names?   => [Name],
      :locations?       => [Location],
      :species_lists?   => [SpeciesList],
      :has_observation? => {:string => [:yes]},
      :size?            => [{:string => Image.all_sizes - [:full_size]}],
      :content_types?   => :string,
      :has_notes?       => :boolean,
      :notes_has?       => :string,
      :copyright_holder_has? => :string,
      :license?         => License,
      :has_votes?       => :boolean,
      :quality?         => [:integer],
      :confidence?      => [:integer],
      :ok_for_export?   => :boolean,
    },
    :Location => {
      :created?  => [:time],
      :modified? => [:time],
      :users?    => [User],
    },
    :LocationDescription => {
      :created?  => [:time],
      :modified? => [:time],
      :users?    => [User],
    },
    :Name => {
      :created?  => [:time],
      :modified? => [:time],
      :users?    => [User],
      :synonym_names? => [:string],
      :misspellings? => {:string => [:no, :either, :only]},
      :deprecated?   => {:string => [:either, :no, :only]},
    },
    :NameDescription => {
      :created?  => [:time],
      :modified? => [:time],
      :users?    => [User],
    },
    :Observation => {
      :created?       => [:time],
      :modified?      => [:time],
      :date?          => [:date],
      :users?         => [User],
      :names?         => [:string],
      :synonym_names? => [:string],
      :locations?     => [:string],
      :species_lists? => [:string],
      :confidence?    => [:integer],
      :is_col_loc?    => :boolean,
      :has_specimen?  => :boolean,
      :has_location?  => :boolean,
      :has_notes?     => :boolean,
      :has_name?      => :boolean,
      :has_images?    => :boolean,
      :has_votes?     => :boolean,
      :has_comments?  => {:string => [:yes]},
      :notes_has?     => :string,
      :comments_has?  => :string,
    },
    :Project => {
      :created?  => [:time],
      :modified? => [:time],
      :users?    => [User],
    },
    :RssLog => {
      :modified? => [:time],
      :type?     => :string,
    },
    :SpeciesList => {
      :created?  => [:time],
      :modified? => [:time],
      :date?     => [:date],
      :users?    => [User],
    },
    :User => {
      :created?  => [:time],
      :modified? => [:time],
    },
  }

  # Parameters required for each flavor.
  self.flavor_params = {
    :advanced_search => {
      :name?     => :string,
      :location? => :string,
      :user?     => :string,
      :content?  => :string,
    },
    :all => {
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
    :for_object => {
      :object => AbstractModel,
      :type   => :string,
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
    :pattern_search => {
      :pattern => :string,
    },
    :with_descriptions_by_author => {
      :user => User,
    },
    :with_descriptions_by_editor => {
      :user => User,
    },
    :with_descriptions_by_user => {
      :user => User,
    },
    :with_descriptions_in_set => {
      :ids        => [AbstractModel],
      :old_title? => :string,
      :old_by?    => :string,
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
      :by_user,               # Comments created by user, by created.
      :in_set,                # Comments in a given set.
      :for_object,            # Comments on a given object, by created.
      :for_user,              # Comments sent to user, by created.
      :pattern_search,        # Comments matching a pattern, by created.
    ],
    :Image => [
      :advanced_search,       # Advanced search results.
      :all,                   # All images, by created.
      :by_user,               # Images created by user, by modified.
      :in_set,                # Images in a given set.
      :inside_observation,    # Images belonging to outer observation query.
      :pattern_search,        # Images matching a pattern, by ???.
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
      :advanced_search,       # Advanced search results.
      :all,                   # All locations, alphabetically.
      :by_user,               # Locations created by a given user, alphabetically.
      :by_editor,             # Locations modified by a given user, alphabetically.
      :by_rss_log,            # Locations with RSS logs, in RSS order.
      :in_set,                # Locations in a given set.
      :pattern_search,        # Locations matching a pattern, alphabetically.
      :with_descriptions,                 # Locations with descriptions, alphabetically.
      :with_descriptions_by_author,       # Locations with descriptions authored by a given user, alphabetically.
      :with_descriptions_by_editor,       # Locations with descriptions edited by a given user, alphabetically.
      :with_descriptions_by_user,         # Locations with descriptions created by a given user, alphabetically.
      :with_descriptions_in_set,          # Locations with descriptions in a given set, alphabetically.
      :with_observations,                 # Locations with observations, alphabetically.
      :with_observations_by_user,         # Locations with observations by user.
      :with_observations_in_set,          # Locations with observations in a given set.
      :with_observations_in_species_list, # Locations with observations in a given species list.
      :with_observations_of_children,     # Locations with observations of children of a given name.
      :with_observations_of_name,         # Locations with observations of a given name.
    ],
    :LocationDescription => [
      :all,                   # All location descriptions, alphabetically.
      :by_author,             # Location descriptions that list given user as an author, alphabetically.
      :by_editor,             # Location descriptions that list given user as an editor, alphabetically.
      :by_user,               # Location descriptions created by a given user, alphabetically.
      :in_set,                # Location descriptions in a given set.
    ],
    :Name => [
      :advanced_search,       # Advanced search results.
      :all,                   # All names, alphabetically.
      :by_user,               # Names created by a given user, alphabetically.
      :by_editor,             # Names modified by a given user, alphabetically.
      :by_rss_log,            # Names with RSS logs, in RSS order.
      :in_set,                # Names in a given set.
      :of_children,           # Names of children of a name.
      :of_parents,            # Names of parents of a name.
      :pattern_search,        # Names matching a pattern, alphabetically.
      :with_descriptions,                 # Names with descriptions, alphabetically.
      :with_descriptions_by_author,       # Names with descriptions authored by a given user, alphabetically.
      :with_descriptions_by_editor,       # Names with descriptions edited by a given user, alphabetically.
      :with_descriptions_by_user,         # Names with descriptions created by a given user, alphabetically.
      :with_descriptions_in_set,          # Names with descriptions in a given set, alphabetically.
      :with_observations,                 # Names with observations, alphabetically.
      :with_observations_at_location,     # Names with observations at a defined location.
      :with_observations_at_where,        # Names with observations at an undefined 'where'.
      :with_observations_by_user,         # Names with observations by user.
      :with_observations_in_set,          # Names with observations in a given set.
      :with_observations_in_species_list, # Names with observations in a given species list.
    ],
    :NameDescription => [
      :all,                   # All name descriptions, alphabetically.
      :by_author,             # Name descriptions that list given user as an author, alphabetically.
      :by_editor,             # Name descriptions that list given user as an editor, alphabetically.
      :by_user,               # Name descriptions created by a given user, alphabetically.
      :in_set,                # Name descriptions in a given set.
    ],
    :Observation => [
      :advanced_search,       # Advanced search results.
      :all,                   # All observations, by date.
      :at_location,           # Observations at a location, by modified.
      :at_where,              # Observations at an undefined location, by modified.
      :by_rss_log,            # Observations with RSS log, in RSS order.
      :by_user,               # Observations created by user, by modified.
      :in_set,                # Observations in a given set.
      :in_species_list,       # Observations in a given species list, by modified.
      :of_children,           # Observations of children of a given name.
      :of_name,               # Observations with a given name.
      :pattern_search,        # Observations matching a pattern, by name.
    ],
    :Project => [
      :all,                   # All projects, by title.
      :by_rss_log,            # Projects with RSS logs, in RSS order.
      :in_set,                # Projects in a given set.
      :pattern_search,        # Projects matching a pattern, by title.
    ],
    :RssLog => [
      :all,                   # All RSS logs, most recent activity first.
      :in_set,                # RSS logs in a given set.
    ],
    :SpeciesList => [
      :all,                   # All species lists, alphabetically.
      :at_location,           # Species lists at a location, by modified.
      :at_where,              # Species lists at an undefined location, by modified.
      :by_rss_log,            # Species lists with RSS log, in RSS order
      :by_user,               # Species lists created by user, alphabetically.
      :in_set,                # Species lists in a given set.
      :pattern_search,        # Species lists matching a pattern, alphabetically.
    ],
    :User => [
      :all,                   # All users, by name.
      :in_set,                # Users in a given set.
      :pattern_search,        # Users matching login/name, alphabetically.
    ],
  }

  # Map each pair of tables to the foreign key name.
  self.join_conditions = {
    :comments => {
      :location_descriptions => :object,
      :locations     => :object,
      :name_descriptions => :object,
      :names         => :object,
      :observations  => :object,
      :projects      => :object,
      :users         => :user_id,
    },
    :images => {
      :users         => :user_id,
      :licenses      => :license_id,
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
    :location_descriptions_versions => {
      :location_descriptions => :location_description_id,
    },
    :location_descriptions_writers => {
      :location_descriptions => :location_description_id,
      :user_groups   => :user_group_id,
    },
    :locations => {
      :licenses      => :license_id,
      :'location_descriptions.default' => :description_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
    },
    :locations_versions => {
      :locations     => :location_id,
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
    :name_descriptions_versions => {
      :name_descriptions => :name_description_id,
    },
    :name_descriptions_writers => {
      :name_descriptions => :name_description_id,
      :user_groups   => :user_group_id,
    },
    :names => {
      :licenses      => :license_id,
      :'name_descriptions.default' => :description_id,
      :rss_logs      => :rss_log_id,
      :users         => :user_id,
      :'users.reviewer' => :reviewer_id,
    },
    :names_versions => {
      :names         => :name_id,
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
      :locations     => :location_id,
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

  # Return the default order for this query.
  def default_order
    case model_symbol
    when :Comment             ; 'created'
    when :Image               ; 'created'
    when :Location            ; 'name'
    when :LocationDescription ; 'name'
    when :Name                ; 'name'
    when :NameDescription     ; 'name'
    when :Observation         ; 'date'
    when :Project             ; 'title'
    when :RssLog              ; 'modified'
    when :SpeciesList         ; 'title'
    when :User                ; 'name'
    end
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

    # Going from list_rss_logs to showing observation, name, etc.
    if (old_model  == :RssLog) and
       (old_flavor == :all) and
       (new_model.to_s.constantize.reflect_on_association(:rss_log) rescue false)
      just_test or begin
        params2 = params.dup
        params2.delete(:type)
        self.class.lookup(new_model, :by_rss_log, params2)
      end

    # Going from objects with observations to those observations themselves.
    elsif ( (new_model == :Observation) and
            [:Image, :Location, :Name].include?(old_model) and
            old_flavor.to_s.match(/^with_observations/) ) or
          ( (new_model == :LocationDescription) and
            (old_model == :Location) and
            old_flavor.to_s.match(/^with_descriptions/) ) or
          ( (new_model == :NameDescription) and
            (old_model == :Name) and
            old_flavor.to_s.match(/^with_descriptions/) )
      just_test or begin
        if old_flavor.to_s.match(/^with_[a-z]+$/)
          new_flavor = :all
        else
          new_flavor = old_flavor.to_s.sub(/^with_[a-z]+_/,'').to_sym
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
    elsif ( (old_model == :Observation) and
            [:Image, :Location, :Name].include?(new_model) ) or
          ( (old_model == :LocationDescription) and
            (new_model == :Location) ) or
          ( (old_model == :NameDescription) and
            (new_model == :Name) )
      just_test or begin
        if old_model == :Observation
          type1 = :observations
          type2 = :observation
        else
          type1 = :descriptions
          type2 = old_model.to_s.underscore.to_sym
        end
        if old_flavor == :all
          new_flavor = :"with_#{type1}"
        else
          new_flavor = :"with_#{type1}_#{old_flavor}"
        end
        params2 = params.dup
        if params2[:title]
          # This can spiral out of control, but so be it.
          params2[:title] = "raw " +
            :"query_title_with_#{type1}s_in_set".
              t(:type1 => title, :type => type2)
        end
        if params2[:by]
          # Can't be sure old sort order will continue to work.
          params2.delete(:by)
        end
        if old_flavor == :in_set
          params2.delete(:title) if params2.has_key?(:title)
          self.class.lookup(new_model, :"with_#{type1}_in_set",
              params2.merge(:old_title => title, :old_by => params[:by]))
        elsif old_flavor == :advanced_search || old_flavor == :pattern_search
          params2.delete(:title) if params2.has_key?(:title)
          self.class.lookup(new_model, :"with_#{type1}_in_set",
              :ids => result_ids, :old_title => title, :old_by => params[:by])
        elsif (new_model == :Location) and
              (old_flavor == :at_location)
          self.class.lookup(new_model, :in_set,
                                     :ids => params2[:location])
        elsif (new_model == :Name) and
              (old_flavor == :of_name)
          # TODO -- need 'synonyms' flavor
          # params[:synonyms] == :all / :no / :exclusive
          # params[:misspellings] == :either / :no / :only
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

  # Allow all queries to customize title.
  def initialize_global
    if args = params[:title]
      for line in args
        raise "Invalid syntax in :title parameter: '#{line}'" if line !~ / /
        title_args[$`.to_sym] = $'
      end
    end
  end

  # ----------------------------
  #  Sort orders.
  # ----------------------------

  # Tell SQL how to sort results using the <tt>:by => :blah</tt> mechanism.
  def initialize_order(by)
    table = model.table_name
    case by

    when 'modified', 'created', 'last_login', 'num_views'
      if model.column_names.include?(by)
        "#{table}.#{by} DESC"
      end

    when 'date'
      if model.column_names.include?('date')
        "#{table}.date DESC"
      elsif model.column_names.include?('when')
        "#{table}.when DESC"
      elsif model.column_names.include?('created')
        "#{table}.created DESC"
      end

    when 'name'
      if model == Image
        self.join << {:images_observations => {:observations => :names}}
        self.group = 'images.id'
        'MIN(names.search_name) ASC, images.when DESC'
      elsif model == Location
        'locations.search_name ASC'
      elsif model == LocationDescription
        self.join << :locations
        'locations.search_name ASC, location_descriptions.created ASC'
      elsif model == Name
        'names.text_name ASC, names.author ASC'
      elsif model == NameDescription
        self.join << :names
        'names.text_name ASC, names.author ASC, name_descriptions.created ASC'
      elsif model == Observation
        self.join << :names
        'names.text_name ASC, names.author ASC, observations.when DESC'
      elsif model.column_names.include?('search_name')
        "#{table}.search_name ASC"
      elsif model.column_names.include?('name')
        "#{table}.name ASC"
      elsif model.column_names.include?('title')
        "#{table}.title ASC"
      end

    when 'title', 'login', 'summary', 'copyright_holder', 'where'
      if model.column_names.include?(by)
        "#{table}.#{by} ASC"
      end

    when 'user'
      if model.column_names.include?('user_id')
        self.join << :users
        'IF(users.name = "" OR users.name IS NULL, users.login, users.name) ASC'
      end

    when 'location'
      if model.column_names.include?('location_id')
        self.join << :locations
        'locations.search_name ASC'
      end

    when 'rss_log'
      if model.column_names.include?('rss_log_id')
        self.join << :rss_logs
        'rss_logs.modified DESC'
      end

    when 'confidence'
      if model_symbol == :Image
        self.join << {:images_observations => :observations}
        "observations.vote_cache DESC"
      elsif model_symbol == :Observation
        "observations.vote_cache DESC"
      end

    when 'image_quality'
      if model_symbol == :Image
        "images.vote_cache DESC"
      end

    when 'thumbnail_quality'
      if model_symbol == :Observation
        self.join << :'images.thumb_image'
        "images.vote_cache DESC, observations.vote_cache DESC"
      end

    when 'contribution'
      if model_symbol == :User
        'users.contribution DESC'
      end
    end
  end

  # ----------------------------
  #  Model customization.
  # ----------------------------

  def initialize_comment
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_comment_types
    initialize_model_do_search(:summary_has, :summary)
    initialize_model_do_search(:content_has, :comment)
  end

  def initialize_image
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_date(:date, :when)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_objects_by_name(
      Name, :names, 'observations.name_id',
      :join => {:images_observations => :observations}
    )
    initialize_model_do_objects_by_name(
      Name, :synonym_names, 'observations.name_id',
      :filter => :synonyms,
      :join => {:images_observations => :observations}
    )
    initialize_model_do_locations('observations',
      :join => {:images_observations => :observations}
    )
    initialize_model_do_locations('observations',
      :join => {:images_observations => :observations}
    )
    initialize_model_do_objects_by_name(
      SpeciesList, :species_lists, 'observations_species_lists.species_list_id',
      :join => {:images_observations => {:observations => :observations_species_lists}}
    )
    if params[:has_observation]
      self.join << :images_observations
    end
    initialize_model_do_image_size
    initialize_model_do_image_types
    initialize_model_do_boolean(:has_notes,
      'LENGTH(COALESCE(images.notes,"")) > 0',
      'LENGTH(COALESCE(images.notes,"")) = 0'
    )
    initialize_model_do_search(:notes_has, :notes)
    initialize_model_do_search(:copyright_holder_has, :copyright_holder)
    initialize_model_do_license
    initialize_model_do_boolean(:has_votes,
      'LENGTH(COALESCE(images.votes,"")) > 0',
      'LENGTH(COALESCE(images.votes,"")) = 0'
    )
    initialize_model_do_range(:quality, :vote_cache)
    initialize_model_do_range(:confidence, 'observations.vote_cache',
      :join => {:images_observations => :observations}
    )
    initialize_model_do_boolean(:ok_for_export,
      'images.ok_for_export IS TRUE',
      'images.ok_for_export IS FALSE'
    )
  end

  def initialize_location
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_objects_by_id(:users)
  end

  def initialize_location_description
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_objects_by_id(:users)
  end

  def initialize_name
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_misspellings
    initialize_model_do_deprecated
    initialize_model_do_objects_by_name(
      Name, :synonym_names, :id, :filter => :synonyms
    )
  end

  def initialize_name_description
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_objects_by_id(:users)
  end

  def initialize_observation
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_date(:date, :when)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_objects_by_name(Name, :names)
    initialize_model_do_objects_by_name(
      Name, :synonym_names, :name_id, :filter => :synonyms
    )
    initialize_model_do_locations
    initialize_model_do_objects_by_name(
      SpeciesList, :species_lists,
      'observations_species_lists.species_list_id',
      :join => :observations_species_lists
    )
    initialize_model_do_range(:confidence, :vote_cache)
    initialize_model_do_search(:notes_has, :notes)
    initialize_model_do_boolean(:is_col_loc,
      'observations.is_collection_location IS TRUE',
      'observations.is_collection_location IS FALSE'
    )
    initialize_model_do_boolean(:has_specimen,
      'observations.specimen IS TRUE',
      'observations.specimen IS FALSE'
    )
    initialize_model_do_boolean(:has_location,
      'observations.location_id IS NOT NULL',
      'observations.location_id IS NULL'
    )
    if !params[:has_name].nil?
      id = Name.unknown.id
      initialize_model_do_boolean(:has_name,
        "observations.name_id != #{id}",
        "observations.name_id == #{id}")
    end
    initialize_model_do_boolean(:has_notes,
      'LENGTH(COALESCE(observations.notes,"")) > 0',
      'LENGTH(COALESCE(observations.notes,"")) = 0'
    )
    initialize_model_do_boolean(:has_images,
      'observations.thumb_image_id IS NOT NULL',
      'observations.thumb_image_id IS NULL'
    )
    initialize_model_do_boolean(:has_votes,
      'observations.vote_cache IS NOT NULL',
      'observations.vote_cache IS NULL'
    )
    if params[:has_comments]
      self.join << :comments
    end
    if !params[:comments_has].blank?
      initialize_model_do_search(:comments_has,
        'CONCAT(comments.summary,comments.notes)')
      self.join << :comments
    end
  end

  def initialize_project
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_objects_by_id(:users)
  end

  def initialize_rss_log
    initialize_model_do_time(:modified)
  end

  def initialize_species_list
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
    initialize_model_do_date(:date, :when)
    initialize_model_do_objects_by_id(:users)
  end

  def initialize_user
    initialize_model_do_time(:created)
    initialize_model_do_time(:modified)
  end

  # -------------------------------
  #  Model customization helpers.
  # -------------------------------

  def initialize_model_do_boolean(arg, true_cond, false_cond)
    if !params[arg].nil?
      self.where << (params[arg] ? true_cond : false_cond)
    end
  end

  def initialize_model_do_search(arg, col=nil)
    if !params[arg].blank?
      col = "#{model.table_name}.#{col}" if !col.to_s.match(/\./)
      search = google_parse(params[arg])
      self.where += google_conditions(search, col)
    end
  end

  def initialize_model_do_range(arg, col, args={})
    if params[arg].is_a?(Array)
      min, max = params[arg]
      self.where << "#{col} >= #{min}" if !min.blank?
      self.where << "#{col} <= #{max}" if !max.blank?
      if (join = args[:join]) and
         (!min.blank? || !max.blank?)
        self.join << join
      end
    end
  end

  def initialize_model_do_deprecated
    case params[:deprecated] || :either
    when :no   ; self.where << 'names.deprecated IS FALSE'
    when :only ; self.where << 'names.deprecated IS TRUE'
    end
  end

  def initialize_model_do_misspellings
    case params[:misspellings] || :no
    when :no   ; self.where << 'names.correct_spelling_id IS NULL'
    when :only ; self.where << 'names.correct_spelling_id IS NOT NULL'
    end
  end

  def initialize_model_do_objects_by_id(arg, col=nil)
    if ids = params[arg]
      col ||= "#{arg.to_s.sub(/s$/,'')}_id"
      col = "#{model.table_name}.#{col}" if !col.to_s.match(/\./)
      set = clean_id_set(ids)
      self.where << "#{col} IN (#{set})"
    end
  end

  def initialize_model_do_objects_by_name(model, arg, col=nil, args={})
    names = params[arg]
    if names && names.any?
      col ||= arg.to_s.sub(/s?$/, '_id')
      col = "#{self.model.table_name}.#{col}" if !col.to_s.match(/\./)
      objs = []
      for name in names
        if name.to_s.match(/^\d+$/)
          obj = model.safe_find(name)
          objs << obj if obj
        else
          case model.name
          when 'Location'
            pattern = clean_pattern(Location.clean_name(name))
            objs += model.all(:conditions => "search_name LIKE '%#{pattern}%'")
          when 'Name'
            objs += model.find_all_by_search_name(name)
            objs += model.find_all_by_text_name(name) if objs.empty?
          when 'SpeciesList'
            objs += model.find_all_by_title(name)
          when 'User'
            name.sub(/ *<.*>/, '')
            objs += model.find_all_by_login(name)
          else
            raise("Forgot to tell initialize_model_do_objects_by_name how " +
                  "to find instances of #{model.name}!")
          end
        end
      end
      if filter = args[:filter]
        objs = objs.uniq.map(&filter).flatten
      end
      if join = args[:join]
        self.join << join
      end
      set = clean_id_set(objs.map(&:id).uniq)
      self.where << "#{col} IN (#{set})"
    end
  end

  def initialize_model_do_locations(table=model.table_name, args={})
    locs = params[:locations]
    if locs && locs.any?
      loc_col = "#{table}.location_id"
      initialize_model_do_objects_by_name(Location, :locations, loc_col, args)
      str = self.where.pop
      for name in locs
        if name.match(/\D/)
          pattern = clean_pattern(name)
          str += " OR #{table}.where LIKE '%#{pattern}%'"
        end
      end
      self.where << str
    end
  end

  def initialize_model_do_comment_types
    if !params[:types].blank?
      types = params[:types].to_s.strip_squeeze.split
      types &= Comment.all_types.map(&:to_s)
      if types.any?
        self.where << "comments.object_type IN ('#{types.join("','")}')"
      end
    end
  end

  def initialize_model_do_image_size
    if params[:size]
      min, max = params[:size]
      sizes  = Image.all_sizes
      pixels = Image.all_sizes_in_pixels
      if min
        size = pixels[sizes.index(min)]
        self.where << "images.width >= #{size} OR images.height >= #{size}"
      end
      if max
        size = pixels[sizes.index(max) + 1]
        self.where << "images.width < #{size} AND images.height < #{size}"
      end
    end
  end

  def initialize_model_do_image_types
    if !params[:content_types].blank?
      exts  = Image.all_extensions.map(&:to_s)
      mimes = Image.all_content_types.map(&:to_s) - ['']
      types = params[:types].to_s.strip_squeeze.split & exts
      if types.any?
        other = types.include?('raw')
        types -= ['raw']
        types = types.map {|x| mimes[exts.index(x)]}
        str1 = "comments.object_type IN ('#{types.join("','")}')"
        str2 = "comments.object_type NOT IN ('#{mimes.join("','")}')"
        if types.empty?
          self.where << str2
        elsif other
          self.where << "#{str1} OR #{str2}"
        else
          self.where << str1
        end
      end
    end
  end

  def initialize_model_do_license
    if !params[:license].blank?
      license = find_cached_parameter_instance(License, :license)
      self.where << "#{model.table_name}.license_id = #{license.id}"
    end
  end

  # ----------------------------
  #  Date customization.
  # ----------------------------

  def initialize_model_do_date(arg=:date, col=arg)
    col = "#{model.table_name}.#{col}" if !col.to_s.match(/\./)
    if vals = params[arg]
      initialize_model_do_date_half(true, vals[0], col)
      initialize_model_do_date_half(false, vals[1], col)
    end
  end

  def initialize_model_do_date_half(min, val, col)
    dir = min ? '>' : '<'
    if val.match(/^\d\d\d\d/)
      y, m, d = val.split('-')
      m ||= min ? 1 : 12
      d ||= min ? 1 : 31
      self.where << "#{col} #{dir}= '%04d-%02d-%02d'" % [y, m, d]
    elsif val.match(/-/)
      m, d = val.split('-')
      self.where << "MONTH(#{col}) #{dir} #{m} OR " +
                    "(MONTH(#{col}) = #{m} AND " +
                    "DAY(#{col}) #{dir}= #{d})"
    elsif !val.blank?
      self.where << "MONTH(#{col}) #{dir}= #{val}"
    end
  end

  def initialize_model_do_time(arg=:time, col=arg)
    col = "#{model.table_name}.#{col}" if !col.to_s.match(/\./)
    if vals = params[arg]
      initialize_model_do_time_half(true, vals[0], col)
      initialize_model_do_time_half(false, vals[1], col)
    end
  end

  def initialize_model_do_time_half(min, val, col)
    if !val.blank?
      dir = min ? '>' : '<'
      y, m, d, h, n, s = val.split('-')
      m ||= min ? 1 : 12
      d ||= min ? 1 : 31
      h ||= min ? 0 : 24
      n ||= min ? 0 : 60
      s ||= min ? 0 : 60
      self.where << "#{col} #{dir}= '%04d-%02d-%02d %02d:%02d:%02d'" %
                                    [y, m, d, h, n, s]
    end
  end

  def validate_date(arg, val)
    if val.acts_like?(:date)
      val = val.in_time_zone
      '%04d-%02d-%02d' % [val.year, val.mon, val.day]
    elsif val.to_s.match(/^\d\d\d\d(-\d\d?){0,2}$/i)
      val
    elsif val.to_s.match(/^\d\d?(-\d\d?)?$/i)
      val
    elsif val.blank? || val.to_s == '0'
      nil
    else
      raise("Value for :#{arg} should be a date (YYYY-MM-DD or MM-DD), got: #{val.inspect}")
    end
  end

  def validate_time(arg, val)
    if val.acts_like?(:time)
      val = val.in_time_zone
      '%04d-%02d-%02d-%02d-%02d-%02d' %
        [val.year, val.mon, val.day, val.hour, val.min, val.sec]
    elsif val.to_s.match(/^\d\d\d\d(-\d\d?){0,5}$/i)
      val
    elsif val.blank? || val.to_s == '0'
      nil
    else
      raise("Value for :#{arg} should be a time (YYYY-MM-DD-HH-MM-SS), got: #{val.inspect}")
    end
  end

  # --------------------------------------------
  #  Queries that essentially have no filters.
  # --------------------------------------------

  def initialize_all
    if (by = params[:by]) and
       (by = :"sort_by_#{by}")
      title_args[:tag]   = :query_title_all_by
      title_args[:order] = by.t
    end

    # Allow users to filter RSS logs for the object type they're interested in.
    if model_symbol == :RssLog
      x = params[:type] ||= 'all'
      types = x.to_s.split
      if !types.include?('all')
        types &= RssLog.all_types
        if types.empty?
          self.where << 'FALSE'
        else
          self.where << types.map do |type|
            "rss_logs.#{type}_id IS NOT NULL"
          end.join(' OR ')
        end
      end
    elsif params[:type]
      raise "Can't use :type parameter in :#{model_symbol} :all queries!"
    end
  end

  def initialize_by_rss_log
    self.join << :rss_logs
    params[:by] ||= 'rss_log'
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
    when :Location, :Name, :LocationDescription, :NameDescription
      params[:by] ||= 'name'
    when :SpeciesList
      params[:by] ||= 'title'
    when :Comment
      params[:by] ||= 'created'
    end
  end

  def initialize_for_object
    type = params[:type].to_s.constantize rescue nil
    if (!type.reflect_on_association(:comments) rescue true)
      raise "The model #{params[:type].inspect} does not support comments!"
    end
    object = find_cached_parameter_instance(type, :object)
    title_args[:object] = object.unique_format_name
    self.where << "comments.object_id = '#{object.id}'"
    self.where << "comments.object_type = '#{type.name}'"
    params[:by] ||= 'created'
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
      version_table = "#{model.table_name}_versions".to_sym
      self.join << version_table
      self.where << "#{version_table}.user_id = '#{params[:user]}'"
      self.where << "#{model.table_name}.user_id != '#{params[:user]}'"
    when :NameDescription, :LocationDescription
      glue_table = "#{model.name.underscore}s_#{flavor}s".
                      sub('_by_', '_').to_sym
      self.join << glue_table
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
    self.where << "#{model.table_name}.location_id = '#{params[:location]}'"
    params[:by] ||= 'name'
  end

  def initialize_at_where
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    self.join << :names
    self.where << "#{model.table_name}.where LIKE '%#{pattern}%'"
    params[:by] ||= 'name'
  end

  def initialize_in_species_list
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    self.join << :names
    self.join << :observations_species_lists
    self.where << "observations_species_lists.species_list_id = '#{params[:species_list]}'"
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
      if nonconsensus == :no
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
    all = params[:all]
    all = false if params[:all].nil?
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

  # ---------------------------------------------------------------
  #  Coercable location/name queries based on description-related
  #  conditions.
  # ---------------------------------------------------------------

  def initialize_with_descriptions
    type = model.name.underscore
    self.join << :"#{type}_descriptions"
    params[:by] ||= 'name'
  end

  def initialize_with_descriptions_by_author
    initialize_with_descriptions_by_editor
  end

  def initialize_with_descriptions_by_editor
    type = model.name.underscore
    glue = flavor.to_s.sub(/^.*_by_/, '')
    desc_table = :"#{type}_descriptions"
    glue_table = :"#{type}_descriptions_#{glue}s"
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.join << { desc_table => glue_table }
    self.where << "#{glue_table}.user_id = '#{params[:user]}'"
    params[:by] ||= 'name'
  end

  def initialize_with_descriptions_by_user
    type = model.name.underscore
    desc_table = :"#{type}_descriptions"
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.join << desc_table
    self.where << "#{desc_table}.user_id = '#{params[:user]}'"
    params[:by] ||= 'name'
  end

  # ----------------------------
  #  Pattern search.
  # ----------------------------

  def initialize_pattern_search
    pattern = params[:pattern].to_s.strip_squeeze
    clean  = clean_pattern(pattern)
    search = google_parse(pattern)

    case model_symbol

      when :Comment
        self.where += google_conditions(search,
          'CONCAT(comments.summary,COALESCE(comments.comment,""))')

      when :Image
        self.join << {:images_observations => {:observations =>
          [:locations!, :names] }}
        self.where += google_conditions(search,
          'CONCAT(names.search_name,' +
          'COALESCE(images.copyright_holder,""),COALESCE(images.notes,""),' +
          'IF(locations.id,locations.search_name,observations.where))')

      when :Location
        self.join << :"location_descriptions.default!"
        note_fields = LocationDescription.all_note_fields.map do |x|
          "COALESCE(location_descriptions.#{x},'')"
        end
        self.where += google_conditions(search,
            "CONCAT(locations.search_name,#{note_fields.join(',')})")

      when :Name
        self.join << :"name_descriptions.default!"
        note_fields = NameDescription.all_note_fields.map do |x|
          "COALESCE(name_descriptions.#{x},'')"
        end
        self.where += google_conditions(search,
            "CONCAT(names.search_name,COALESCE(names.citation,'')," +
                    "COALESCE(names.notes,''),#{note_fields.join(',')})")

      when :Observation
        self.join << [:locations!, :names]
        self.where += google_conditions(search,
          'CONCAT(names.search_name,COALESCE(observations.notes,""),' +
          'IF(locations.id,locations.search_name,observations.where))')

      when :Project
        self.where += google_conditions(search,
          'CONCAT(projects.title,COALESCE(projects.summary,""))')

      when :SpeciesList
        self.join << :locations!
        self.where += google_conditions(search,
          'CONCAT(species_lists.title,COALESCE(species_lists.notes,""),' +
          'IF(locations.id,locations.search_name,species_lists.where))')

      when :User
        self.where += google_conditions(search,
          'CONCAT(users.login,users.name)')

      else
        raise "Forgot to tell me how to build a :#{flavor} query for #{model}!"
      end
    end

  # ----------------------------
  #  Advanced search.
  # ----------------------------

  def initialize_advanced_search
    name     = google_parse(params[:name])
    user     = google_parse(params[:user].to_s.gsub(/ *<[^<>]*>/, ''))
    location = google_parse(params[:location])
    content  = google_parse(params[:content])

    # Force user to enter *something*.
    if name.blank? and user.blank? and location.blank? and content.blank?
      raise :runtime_no_conditions.t
    end

    # This case is a disaster.  Perform it as an observation query, then
    # coerce into images.
    if (model_symbol == :Image) and !content.blank?
      self.executor = lambda do |args|
        args2 = args.dup
        args2.delete(:select)
        params2 = params.dup
        params2.delete(:by)
        ids = self.class.lookup(:Observation, flavor, params2).result_ids(args2)
        ids = clean_id_set(ids)
        args2 = args.dup
        extend_join(args2)  << :images_observations
        extend_where(args2) << "images_observations.observation_id IN (#{ids})"
        model.connection.select_rows(query(args2))
      end
      return
    end

    case model_symbol
    when :Image
      self.join << {:images_observations => {:observations => :users}}      if !user.blank?
      self.join << {:images_observations => {:observations => :names}}      if !name.blank?
      self.join << {:images_observations => {:observations => :locations!}} if !location.blank?
      self.join << {:images_observations => :observations}                  if !content.blank?
    when :Location
      self.join << {:observations => :users} if !user.blank?
      self.join << {:observations => :names} if !name.blank?
      self.join << :observations             if !content.blank?
    when :Name
      self.join << {:observations => :users}      if !user.blank?
      self.join << {:observations => :locations!} if !location.blank?
      self.join << :observations                  if !content.blank?
    when :Observation
      self.join << :names      if !name.blank?
      self.join << :users      if !user.blank?
      self.join << :locations! if !location.blank?
    end

    # Name of mushroom...
    if !name.blank?
      self.where += google_conditions(name, 'names.search_name')
    end

    # Who observed the mushroom...
    if !user.blank?
      self.where += google_conditions(user, 'CONCAT(users.login,users.name)')
    end

    # Where the mushroom was seen...
    if !location.blank?
      if model_symbol == :Location
        self.where += google_conditions(location, 'locations.search_name')
      else
        self.where += google_conditions(location,
          'IF(locations.id,locations.search_name,observations.where)')
      end
    end

    # Content of observation and comments...
    if !content.blank?

      # # This was the old query using left outer join to include comments.
      # self.join << case model_symbol
      # when :Image       ; {:images_observations => {:observations => :comments!}}
      # when :Location    ; {:observations => :comments!}
      # when :Name        ; {:observations => :comments!}
      # when :Observation ; :comments!
      # end
      # self.where += google_conditions(content,
      #   'CONCAT(observations.notes,IF(comments.id,CONCAT(comments.summary,comments.comment),""))')

      # Cannot do left outer join from observations to comments, because it
      # will never return.  Instead, break it into two queries, one without
      # comments, and another with inner join on comments.
      self.executor = lambda do |args|
        args2 = args.dup
        extend_where(args2)
        args2[:where] += google_conditions(content, 'observations.notes')
        results = model.connection.select_rows(query(args2))

        args2 = args.dup
        extend_join(args2) << case model_symbol
        when :Image       ; {:images_observations => {:observations => :comments}}
        when :Location    ; {:observations => :comments}
        when :Name        ; {:observations => :comments}
        when :Observation ; :comments
        end
        extend_where(args2)
        args2[:where] += google_conditions(content,
          'CONCAT(observations.notes,comments.summary,comments.comment)')
        results |= model.connection.select_rows(query(args2))
      end
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
      extend_join(outer.params) << :images_observations
    end
  end
end
