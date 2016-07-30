# encoding: utf-8
#
#  = Query Model
#
################################################################################

class Query < AbstractQuery
  belongs_to :user

  # enum definitions for use by simple_enum gem
  # Do not change the integer associated with a value
  as_enum(:flavor,
          { advanced_search: 1,
            all: 2,
            at_location: 3,
            at_where: 4,
            by_author: 5,
            by_editor: 6,
            by_rss_log: 7,
            by_user: 8,
            for_project: 9,
            for_target: 10,
            for_user: 11,
            in_set: 12,
            in_species_list: 13,
            inside_observation: 14,
            of_children: 15,
            of_name: 16,
            of_parents: 17,
            pattern_search: 18,
            regexp_search: 19,
            with_descriptions: 20,
            with_descriptions_by_author: 21,
            with_descriptions_by_editor: 22,
            with_descriptions_by_user: 23,
            with_descriptions_in_set: 24,
            with_observations: 25,
            with_observations_at_location: 26,
            with_observations_at_where: 27,
            with_observations_by_user: 28,
            with_observations_for_project: 29,
            with_observations_in_set: 30,
            with_observations_in_species_list: 31,
            with_observations_of_children: 32,
            with_observations_of_name: 33
          },
          source: :flavor,
          with: [],
          accessor: :whiny
         )
  as_enum(:model,
          { Comment: 1,
            Herbarium: 2,
            Image: 3,
            Location: 4,
            LocationDescription: 5,
            Name: 6,
            NameDescription: 7,
            Observation: 8,
            Project: 9,
            RssLog: 10,
            SpeciesList: 11,
            Specimen: 12,
            User: 13
          },
          source: :model,
          with: [],
          accessor: :whiny
         )

  # Parameters allowed in every query.
  self.global_params = {
    # Allow every query to customize its title.
    title?: [:string]
  }

  # Parameters allowed in every query for a given model.
  self.model_params = {
    Comment: {
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      types?: :string,
      summary_has?: :string,
      content_has?: :string
    },
    Image: {
      created_at?: [:time],
      updated_at?: [:time],
      date?: [:date],
      users?: [User],
      names?: [:string],
      synonym_names?: [:string],
      children_names?: [:string],
      locations?: [:string],
      projects?: [:string],
      species_lists?: [:string],
      has_observation?: { string: [:yes] },
      size?: [{ string: Image.all_sizes - [:full_size] }],
      content_types?: :string,
      has_notes?: :boolean,
      notes_has?: :string,
      copyright_holder_has?: :string,
      license?: License,
      has_votes?: :boolean,
      quality?: [:float],
      confidence?: [:float],
      ok_for_export?: :boolean
    },
    Location: {
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      north?: :float,
      south?: :float,
      east?: :float,
      west?: :float
    },
    LocationDescription: {
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User]
    },
    Name: {
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      names?: [:string],
      synonym_names?: [:string],
      children_names?: [:string],
      misspellings?: { string: [:no, :either, :only] },
      deprecated?: { string: [:either, :no, :only] },
      has_synonyms?: :boolean,
      locations?: [:string],
      species_lists?: [:string],
      rank?: [{ string: Name.all_ranks }],
      is_deprecated?: :boolean,
      text_name_has?: :string,
      has_author?: :boolean,
      author_has?: :string,
      has_citation?: :boolean,
      citation_has?: :string,
      has_classification?: :boolean,
      classification_has?: :string,
      has_notes?: :boolean,
      notes_has?: :string,
      has_comments?: { string: [:yes] },
      comments_has?: :string,
      has_default_desc?: :boolean,
      join_desc?: { string: [:default, :any] },
      desc_type?: :string,
      desc_project?: [:string],
      desc_creator?: [User],
      desc_content?: :string,
      ok_for_export?: :boolean
    },
    NameDescription: {
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User]
    },
    Observation: {
      created_at?: [:time],
      updated_at?: [:time],
      date?: [:date],
      users?: [User],
      names?: [:string],
      synonym_names?: [:string],
      children_names?: [:string],
      locations?: [:string],
      projects?: [:string],
      species_lists?: [:string],
      confidence?: [:float],
      is_col_loc?: :boolean,
      has_specimen?: :boolean,
      has_location?: :boolean,
      has_notes?: :boolean,
      has_name?: :boolean,
      has_images?: :boolean,
      has_votes?: :boolean,
      has_comments?: { string: [:yes] },
      notes_has?: :string,
      comments_has?: :string,
      north?: :float,
      south?: :float,
      east?: :float,
      west?: :float,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    },
    Project: {
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      has_images?: { string: [:yes] },
      has_observations?: { string: [:yes] },
      has_species_lists?: { string: [:yes] },
      has_comments?: { string: [:yes] },
      has_notes?: :boolean,
      title_has?: :string,
      notes_has?: :string,
      comments_has?: :string
    },
    RssLog: {
      updated_at?: [:time],
      type?: :string
    },
    SpeciesList: {
      created_at?: [:time],
      updated_at?: [:time],
      date?: [:date],
      users?: [User],
      names?: [:string],
      synonym_names?: [:string],
      children_names?: [:string],
      locations?: [:string],
      projects?: [:string],
      title_has?: :string,
      has_notes?: :boolean,
      notes_has?: :string,
      has_comments?: { string: [:yes] },
      comments_has?: :string
    },
    User: {
      created_at?: [:time],
      updated_at?: [:time]
    }
  }

  # Parameters required for each flavor.
  self.flavor_params = {
    advanced_search: {
      name?: :string,
      location?: :string,
      user?: :string,
      content?: :string,
      search_location_notes?: :boolean
    },
    all: {
    },
    at_location: {
      location: Location
    },
    at_where: {
      location: :string,
      user_where: :string
    },
    by_author: {
      user: User
    },
    by_editor: {
      user: User
    },
    by_user: {
      user: User
    },
    for_project: {
      project: Project
    },
    for_target: {
      target: AbstractModel,
      type: :string
    },
    for_user: {
      user: User
    },
    in_set: {
      ids: [AbstractModel]
    },
    in_species_list: {
      species_list: SpeciesList
    },
    inside_observation: {
      observation: Observation,
      outer: self, # Used to be Query, but that is now ambiguous
    },
    of_children: {
      name: Name,
      all?: :boolean
    },
    of_name: {
      name: :name,
      synonyms?: { string: [:no, :all, :exclusive] },
      nonconsensus?: { string: [:no, :all, :exclusive] },
      project?: Project,
      species_list?: SpeciesList,
      user?: User
    },
    of_parents: {
      name: Name
    },
    pattern_search: {
      pattern: :string
    },
    regexp_search: {
      regexp: :string
    },
    with_descriptions_by_author: {
      user: User
    },
    with_descriptions_by_editor: {
      user: User
    },
    with_descriptions_by_user: {
      user: User
    },
    with_descriptions_in_set: {
      ids: [AbstractModel],
      old_title?: :string,
      old_by?: :string
    },
    with_observations_at_location: {
      location: Location,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    },
    with_observations_at_where: {
      location: :string,
      user_where: :string,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    },
    with_observations_by_user: {
      user: User,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    },
    with_observations_for_project: {
      project: Project,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    },
    with_observations_in_set: {
      ids: [Observation],
      old_title?: :string,
      old_by?: :string,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    },
    with_observations_in_species_list: {
      species_list: SpeciesList,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    },
    with_observations_of_children: {
      name: Name,
      all?: :boolean,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    },
    with_observations_of_name: {
      name: :name,
      synonyms?: { string: [:no, :all, :exclusive] },
      nonconsensus?: { string: [:no, :all, :exclusive] },
      project?: Project,
      species_list?: SpeciesList,
      user?: User,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    }
  }

  # Allowed flavors for each model.
  self.allowed_model_flavors = {
    Comment: [
      :all, # All comments, by created.
      :by_user, # Comments created by user, by created.
      :in_set, # Comments in a given set.
      :for_target, # Comments on a given object, by created.
      :for_user, # Comments sent to user, by created.
      :pattern_search, # Comments matching a pattern, by created.
    ],
    Herbarium: [
      :all,
      :pattern_search
    ],
    Image: [
      :advanced_search, # Advanced search results.
      :all, # All images, by created.
      :by_user, # Images created by user, by updated.
      :for_project, # Images attached to a given project.
      :in_set, # Images in a given set.
      :inside_observation, # Images belonging to outer observation query.
      :pattern_search, # Images matching a pattern, by ???.
      :with_observations, # Images with observations, alphabetically.
      :with_observations_at_location, # Images with observations at a defined location.
      :with_observations_at_where, # Images with observations at an undefined 'where'.
      :with_observations_by_user, # Images with observations by user.
      :with_observations_for_project, # Images with observations attached to given project.
      :with_observations_in_set, # Images with observations in a given set.
      :with_observations_in_species_list, # Images with observations in a given species list.
      :with_observations_of_children, # Images with observations of children a given name.
      :with_observations_of_name, # Images with observations of a given name.
    ],
    Location: [
      :advanced_search, # Advanced search results.
      :all, # All locations, alphabetically.
      :by_user, # Locations created by a given user, alphabetically.
      :by_editor, # Locations updated by a given user, alphabetically.
      :by_rss_log, # Locations with RSS logs, in RSS order.
      :in_set, # Locations in a given set.
      :pattern_search, # Locations matching a pattern, alphabetically.
      :regexp_search, # Locations matching a pattern, alphabetically.
      :with_descriptions, # Locations with descriptions, alphabetically.
      :with_descriptions_by_author, # Locations with descriptions authored by a given user, alphabetically.
      :with_descriptions_by_editor, # Locations with descriptions edited by a given user, alphabetically.
      :with_descriptions_by_user, # Locations with descriptions created by a given user, alphabetically.
      :with_descriptions_in_set, # Locations with descriptions in a given set, alphabetically.
      :with_observations, # Locations with observations, alphabetically.
      :with_observations_by_user, # Locations with observations by user.
      :with_observations_for_project, # Locations with observations attached to given project.
      :with_observations_in_set, # Locations with observations in a given set.
      :with_observations_in_species_list, # Locations with observations in a given species list.
      :with_observations_of_children, # Locations with observations of children of a given name.
      :with_observations_of_name, # Locations with observations of a given name.
    ],
    LocationDescription: [
      :all, # All location descriptions, alphabetically.
      :by_author, # Location descriptions that list given user as an author, alphabetically.
      :by_editor, # Location descriptions that list given user as an editor, alphabetically.
      :by_user, # Location descriptions created by a given user, alphabetically.
      :in_set, # Location descriptions in a given set.
    ],
    Name: [
      :advanced_search, # Advanced search results.
      :all, # All names, alphabetically.
      :by_user, # Names created by a given user, alphabetically.
      :by_editor, # Names updated by a given user, alphabetically.
      :by_rss_log, # Names with RSS logs, in RSS order.
      :in_set, # Names in a given set.
      :of_children, # Names of children of a name.
      :of_parents, # Names of parents of a name.
      :pattern_search, # Names matching a pattern, alphabetically.
      :with_descriptions, # Names with descriptions, alphabetically.
      :with_descriptions_by_author, # Names with descriptions authored by a given user, alphabetically.
      :with_descriptions_by_editor, # Names with descriptions edited by a given user, alphabetically.
      :with_descriptions_by_user, # Names with descriptions created by a given user, alphabetically.
      :with_descriptions_in_set, # Names with descriptions in a given set, alphabetically.
      :with_observations, # Names with observations, alphabetically.
      :with_observations_at_location, # Names with observations at a defined location.
      :with_observations_at_where, # Names with observations at an undefined 'where'.
      :with_observations_by_user, # Names with observations by user.
      :with_observations_for_project, # Names with observations attached to given project.
      :with_observations_in_set, # Names with observations in a given set.
      :with_observations_in_species_list, # Names with observations in a given species list.
    ],
    NameDescription: [
      :all, # All name descriptions, alphabetically.
      :by_author, # Name descriptions that list given user as an author, alphabetically.
      :by_editor, # Name descriptions that list given user as an editor, alphabetically.
      :by_user, # Name descriptions created by a given user, alphabetically.
      :in_set, # Name descriptions in a given set.
    ],
    Observation: [
      :advanced_search, # Advanced search results.
      :all, # All observations, by date.
      :at_location, # Observations at a location, by updated_at.
      :at_where, # Observations at an undefined location, by updated_at.
      :by_rss_log, # Observations with RSS log, in RSS order.
      :by_user, # Observations created by user, by updated_at.
      :for_project, # Observations attached to a given project.
      :in_set, # Observations in a given set.
      :in_species_list, # Observations in a given species list, by updated_at.
      :of_children, # Observations of children of a given name.
      :of_name, # Observations with a given name.
      :pattern_search, # Observations matching a pattern, by name.
    ],
    Project: [
      :all, # All projects, by title.
      :by_rss_log, # Projects with RSS logs, in RSS order.
      :in_set, # Projects in a given set.
      :pattern_search, # Projects matching a pattern, by title.
    ],
    RssLog: [
      :all, # All RSS logs, most recent activity first.
      :in_set, # RSS logs in a given set.
    ],
    SpeciesList: [
      :all, # All species lists, alphabetically.
      :at_location, # Species lists at a location, by updated_at.
      :at_where, # Species lists at an undefined location, by updated_at.
      :by_rss_log, # Species lists with RSS log, in RSS order
      :by_user, # Species lists created by user, alphabetically.
      :for_project, # Species lists attached to a given project.
      :in_set, # Species lists in a given set.
      :pattern_search, # Species lists matching a pattern, alphabetically.
    ],
    Specimen: [
      :all,
      :pattern_search
    ],
    User: [
      :all, # All users, by name.
      :in_set, # Users in a given set.
      :pattern_search, # Users matching login/name, alphabetically.
    ]
  }

  # Map each pair of tables to the foreign key name.
  self.join_conditions = {
    comments: {
      location_descriptions: :target,
      locations: :target,
      name_descriptions: :target,
      names: :target,
      observations: :target,
      projects: :target,
      species_lists: :target,
      users: :user_id
    },
    image_votes: {
      images: :image_id,
      users: :user_id
    },
    images: {
      users: :user_id,
      licenses: :license_id
    },
    images_observations: {
      images: :image_id,
      observations: :observation_id
    },
    images_projects: {
      images: :image_id,
      projects: :project_id
    },
    interests: {
      locations: :target,
      names: :target,
      observations: :target,
      users: :user_id
    },
    location_descriptions: {
      locations: :location_id,
      users: :user_id
    },
    location_descriptions_admins: {
      location_descriptions: :location_description_id,
      user_groups: :user_group_id
    },
    location_descriptions_authors: {
      location_descriptions: :location_description_id,
      users: :user_id
    },
    location_descriptions_editors: {
      location_descriptions: :location_description_id,
      users: :user_id
    },
    location_descriptions_readers: {
      location_descriptions: :location_description_id,
      user_groups: :user_group_id
    },
    location_descriptions_versions: {
      location_descriptions: :location_description_id
    },
    location_descriptions_writers: {
      location_descriptions: :location_description_id,
      user_groups: :user_group_id
    },
    locations: {
      licenses: :license_id,
      :'location_descriptions.default' => :description_id,
      rss_logs: :rss_log_id,
      users: :user_id
    },
    locations_versions: {
      locations: :location_id
    },
    name_descriptions: {
      names: :name_id,
      users: :user_id
    },
    name_descriptions_admins: {
      name_descriptions: :name_description_id,
      user_groups: :user_group_id
    },
    name_descriptions_authors: {
      name_descriptions: :name_description_id,
      users: :user_id
    },
    name_descriptions_editors: {
      name_descriptions: :name_description_id,
      users: :user_id
    },
    name_descriptions_readers: {
      name_descriptions: :name_description_id,
      user_groups: :user_group_id
    },
    name_descriptions_versions: {
      name_descriptions: :name_description_id
    },
    name_descriptions_writers: {
      name_descriptions: :name_description_id,
      user_groups: :user_group_id
    },
    names: {
      licenses: :license_id,
      :'name_descriptions.default' => :description_id,
      rss_logs: :rss_log_id,
      users: :user_id,
      :'users.reviewer' => :reviewer_id
    },
    names_versions: {
      names: :name_id
    },
    namings: {
      names: :name_id,
      observations: :observation_id,
      users: :user_id
    },
    notifications: {
      names: :obj,
      users: :user_id
    },
    observations: {
      locations: :location_id,
      names: :name_id,
      rss_logs: :rss_log_id,
      users: :user_id,
      :'images.thumb_image' => :thumb_image_id,
      :'image_votes.thumb_image' => [:thumb_image_id, :image_id]
    },
    observations_projects: {
      observations: :observation_id,
      projects: :project_id
    },
    observations_species_lists: {
      observations: :observation_id,
      species_lists: :species_list_id
    },
    projects: {
      users: :user_id,
      user_groups: :user_group_id,
      :'user_groups.admin_group' => :admin_group_id
    },
    projects_species_lists: {
      projects: :project_id,
      species_lists: :species_list_id
    },
    rss_logs: {
      locations: :location_id,
      names: :name_id,
      observations: :observation_id,
      species_lists: :species_list_id
    },
    species_lists: {
      locations: :location_id,
      rss_logs: :rss_log_id,
      users: :user_id
    },
    user_groups_users: {
      user_groups: :user_group_id,
      users: :user_id
    },
    users: {
      images: :image_id,
      licenses: :license_id,
      locations: :location_id
    },
    votes: {
      namings: :naming_id,
      observations: :observation_id,
      users: :user_id
    }
  }

  # Return the default order for this query.
  def default_order # This should be in each of the classes not here!
    case model_symbol
    when :Comment then "created_at"
    when :Herbarium then "name"
    when :Image then "created_at"
    when :Location then "name"
    when :LocationDescription then "name"
    when :Name then "name"
    when :NameDescription then "name"
    when :Observation then "date"
    when :Project then "title"
    when :RssLog then "updated_at"
    when :SpeciesList then "title"
    when :Specimen then "herbarium_label"
    when :User then "name"
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
    initialize_query unless initialized?
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
  def coerce(new_model, just_test = false)
    old_model  = model_symbol
    old_flavor = flavor
    new_model  = new_model.to_s.to_sym

    # Going from list_rss_logs to showing observation, name, etc.
    if (old_model == :RssLog) &&
       (old_flavor == :all) &&
       (begin
          new_model.to_s.constantize.reflect_on_association(:rss_log)
        rescue
          false
        end)
      just_test || begin
        params2 = params.dup
        params2.delete(:type)
        self.class.lookup(new_model, :by_rss_log, params2)
      end

    # Going from objects with observations to those observations themselves.
    elsif ((new_model == :Observation) &&
            [:Image, :Location, :Name].include?(old_model) &&
            old_flavor.to_s.match(/^with_observations/)) ||
          ((new_model == :LocationDescription) &&
            (old_model == :Location) &&
            old_flavor.to_s.match(/^with_descriptions/)) ||
          ((new_model == :NameDescription) &&
            (old_model == :Name) &&
            old_flavor.to_s.match(/^with_descriptions/))
      just_test || begin
        if old_flavor.to_s.match(/^with_[a-z]+$/)
          new_flavor = :all
        else
          new_flavor = old_flavor.to_s.sub(/^with_[a-z]+_/, "").to_sym
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
    elsif ((old_model == :Observation) &&
            [:Image, :Location, :Name].include?(new_model)) ||
          ((old_model == :LocationDescription) &&
            (new_model == :Location)) ||
          ((old_model == :NameDescription) &&
            (new_model == :Name))
      just_test || begin
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
                            :"query_title_with_#{type2}s_in_set".
                            t(observations: title, type: new_model.to_s.underscore.to_sym)
        end
        if params2[:by]
          # Can't be sure old sort order will continue to work.
          params2.delete(:by)
        end
        if old_flavor == :in_set
          params2.delete(:title) if params2.key?(:title)
          self.class.lookup(new_model, :"with_#{type1}_in_set",
                            params2.merge(old_title: title, old_by: params[:by]))
        elsif old_flavor == :advanced_search || old_flavor == :pattern_search
          params2.delete(:title) if params2.key?(:title)
          self.class.lookup(new_model, :"with_#{type1}_in_set",
                            ids: result_ids, old_title: title, old_by: params[:by])
        elsif (new_model == :Location) &&
              (old_flavor == :at_location)
          self.class.lookup(new_model, :in_set,
                            ids: params2[:location])
        elsif (new_model == :Name) &&
              (old_flavor == :of_name)
          # TODO: -- need 'synonyms' flavor
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
      tag: "query_title_#{flavor}".to_sym,
      type: model_string.underscore.to_sym
    )
    super
  end

  # Allow all queries to customize title.
  def initialize_global
    if args = params[:title]
      for line in args
        fail "Invalid syntax in :title parameter: '#{line}'" if line !~ / /
        title_args[$`.to_sym] = $'
      end
    end
  end

  # ----------------------------
  #  Sort orders.
  # ----------------------------

  # Tell SQL how to sort results using the <tt>:by => :blah</tt> mechanism.
  def initialize_order(by)
    table = model_class.table_name
    case by

    when "updated_at", "created_at", "last_login", "num_views"
      "#{table}.#{by} DESC" if model_class.column_names.include?(by)

    when "date"
      if model_class.column_names.include?("date")
        "#{table}.date DESC"
      elsif model_class.column_names.include?("when")
        "#{table}.when DESC"
      elsif model_class.column_names.include?("created_at")
        "#{table}.created_at DESC"
      end

    when "name"
      if model_class == Image
        add_join(:images_observations, :observations)
        add_join(:observations, :names)
        self.group = "images.id"
        "MIN(names.sort_name) ASC, images.when DESC"
      elsif model_class == Location
        User.current_location_format == :scientific ?
          "locations.scientific_name ASC" : "locations.name ASC"
      elsif model_class == LocationDescription
        add_join(:locations)
        "locations.name ASC, location_descriptions.created_at ASC"
      elsif model_class == Name
        "names.sort_name ASC"
      elsif model_class == NameDescription
        add_join(:names)
        "names.sort_name ASC, name_descriptions.created_at ASC"
      elsif model_class == Observation
        add_join(:names)
        "names.sort_name ASC, observations.when DESC"
      elsif model_class.column_names.include?("sort_name")
        "#{table}.sort_name ASC"
      elsif model_class.column_names.include?("name")
        "#{table}.name ASC"
      elsif model_class.column_names.include?("title")
        "#{table}.title ASC"
      end

    when "title", "login", "summary", "copyright_holder", "where"
      "#{table}.#{by} ASC" if model_class.column_names.include?(by)

    when "user"
      if model_class.column_names.include?("user_id")
        add_join(:users)
        'IF(users.name = "" OR users.name IS NULL, users.login, users.name) ASC'
      end

    when "location"
      if model_class.column_names.include?("location_id")
        add_join(:locations)
        User.current_location_format == :scientific ?
          "locations.scientific_name ASC" : "locations.name ASC"
      end

    when "rss_log"
      if model_class.column_names.include?("rss_log_id")
        add_join(:rss_logs)
        "rss_logs.updated_at DESC"
      end

    when "confidence"
      if model_symbol == :Image
        add_join(:images_observations, :observations)
        "observations.vote_cache DESC"
      elsif model_symbol == :Observation
        "observations.vote_cache DESC"
      end

    when "image_quality"
      "images.vote_cache DESC" if model_symbol == :Image

    when "thumbnail_quality"
      if model_symbol == :Observation
        add_join(:'images.thumb_image')
        "images.vote_cache DESC, observations.vote_cache DESC"
      end

    when "owners_quality"
      if model_symbol == :Image
        add_join(:image_votes)
        where << "image_votes.user_id = images.user_id"
        "image_votes.value DESC"
      end

    when "owners_thumbnail_quality"
      if model_symbol == :Observation
        add_join(:'images.thumb_image', :image_votes)
        where << "images.user_id = observations.user_id"
        where << "image_votes.user_id = observations.user_id"
        "image_votes.value DESC, images.vote_cache DESC, observations.vote_cache DESC"
      end

    when "contribution"
      "users.contribution DESC" if model_symbol == :User

    when "original_name"
      "images.original_name ASC" if model_symbol == :Image
    end
  end

  # ----------------------------
  #  Model customization.
  # ----------------------------

  def initialize_comment
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_enum_set(:types, :target_type, Comment.all_types, :string)
    initialize_model_do_search(:summary_has, :summary)
    initialize_model_do_search(:content_has, :comment)
  end

  def initialize_image
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_date(:date, :when)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_objects_by_name(
      Name, :names, "observations.name_id",
      join: { images_observations: :observations }
    )
    initialize_model_do_objects_by_name(
      Name, :synonym_names, "observations.name_id",
      filter: :synonyms,
      join: { images_observations: :observations }
    )
    initialize_model_do_objects_by_name(
      Name, :children_names, "observations.name_id",
      filter: :all_children,
      join: { images_observations: :observations }
    )
    initialize_model_do_locations("observations",
                                  join: { images_observations: :observations }
                                 )
    initialize_model_do_objects_by_name(
      Project, :projects, "images_projects.project_id",
      join: :images_projects
    )
    initialize_model_do_objects_by_name(
      SpeciesList, :species_lists, "observations_species_lists.species_list_id",
      join: { images_observations: { observations: :observations_species_lists } }
    )
    add_join(:images_observations) if params[:has_observation]
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
    initialize_model_do_range(:confidence, "observations.vote_cache",
                              join: { images_observations: :observations }
                             )
    initialize_model_do_boolean(:ok_for_export,
                                "images.ok_for_export IS TRUE",
                                "images.ok_for_export IS FALSE"
                               )
  end

  def initialize_location
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_bounding_box(:location)
  end

  def initialize_location_description
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
  end

  def initialize_name
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_misspellings
    initialize_model_do_deprecated
    initialize_model_do_objects_by_name(
      Name, :names, :id
    )
    initialize_model_do_objects_by_name(
      Name, :synonym_names, :id, filter: :synonyms
    )
    initialize_model_do_objects_by_name(
      Name, :children_names, :id, filter: :all_children
    )
    initialize_model_do_locations("observations", join: :observations)
    initialize_model_do_objects_by_name(
      SpeciesList, :species_lists,
      "observations_species_lists.species_list_id",
      join: { observations: :observations_species_lists }
    )
    initialize_model_do_rank
    initialize_model_do_boolean(:is_deprecated,
                                "names.deprecated IS TRUE",
                                "names.deprecated IS FALSE"
                               )
    initialize_model_do_boolean(:has_synonyms,
                                "names.synonym_id IS NOT NULL",
                                "names.synonym_id IS NULL"
                               )
    initialize_model_do_boolean(:ok_for_export,
                                "names.ok_for_export IS TRUE",
                                "names.ok_for_export IS FALSE"
                               )
    unless params[:text_name_has].blank?
      initialize_model_do_search(:text_name_has, "text_name")
    end
    initialize_model_do_boolean(:has_author,
                                'LENGTH(COALESCE(names.author,"")) > 0',
                                'LENGTH(COALESCE(names.author,"")) = 0'
                               )
    unless params[:author_has].blank?
      initialize_model_do_search(:author_has, "author")
    end
    initialize_model_do_boolean(:has_citation,
                                'LENGTH(COALESCE(names.citation,"")) > 0',
                                'LENGTH(COALESCE(names.citation,"")) = 0'
                               )
    unless params[:citation_has].blank?
      initialize_model_do_search(:citation_has, "citation")
    end
    initialize_model_do_boolean(:has_classification,
                                'LENGTH(COALESCE(names.classification,"")) > 0',
                                'LENGTH(COALESCE(names.classification,"")) = 0'
                               )
    unless params[:classification_has].blank?
      initialize_model_do_search(:classification_has, "classification")
    end
    initialize_model_do_boolean(:has_notes,
                                'LENGTH(COALESCE(names.notes,"")) > 0',
                                'LENGTH(COALESCE(names.notes,"")) = 0'
                               )
    unless params[:notes_has].blank?
      initialize_model_do_search(:notes_has, "notes")
    end
    add_join(:comments) if params[:has_comments]
    unless params[:comments_has].blank?
      initialize_model_do_search(:comments_has,
                                 "CONCAT(comments.summary,comments.notes)")
      add_join(:comments)
    end
    initialize_model_do_boolean(:has_default_desc,
                                "names.description_id IS NOT NULL",
                                "names.description_id IS NULL"
                               )
    if params[:join_desc] == :default
      add_join(:'name_descriptions.default')
    elsif (params[:join_desc] == :any) ||
          !params[:desc_type].blank? ||
          !params[:desc_project].blank? ||
          !params[:desc_creator].blank? ||
          !params[:desc_content].blank?
      add_join(:name_descriptions)
    end
    initialize_model_do_enum_set(:desc_type,
                                 "name_descriptions.source_type", Description.all_source_types, :integer
                                )
    initialize_model_do_objects_by_name(
      Project, :desc_project, "name_descriptions.project_id"
    )
    initialize_model_do_objects_by_name(
      User, :desc_creator, "name_descriptions.user_id"
    )
    fields = NameDescription.all_note_fields
    fields = fields.map { |f| "COALESCE(name_descriptions.#{f},'')" }
    initialize_model_do_search(:desc_content, "CONCAT(#{fields.join(",")})")
  end

  def initialize_name_description
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
  end

  def initialize_observation
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_date(:date, :when)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_objects_by_name(Name, :names)
    initialize_model_do_objects_by_name(
      Name, :synonym_names, :name_id, filter: :synonyms
    )
    initialize_model_do_objects_by_name(
      Name, :children_names, :name_id, filter: :all_children
    )
    initialize_model_do_locations
    initialize_model_do_objects_by_name(
      Project, :projects, "observations_projects.project_id",
      join: :observations_projects
    )
    initialize_model_do_objects_by_name(
      SpeciesList, :species_lists,
      "observations_species_lists.species_list_id",
      join: :observations_species_lists
    )
    initialize_model_do_range(:confidence, :vote_cache)
    initialize_model_do_search(:notes_has, :notes)
    initialize_model_do_boolean(:is_col_loc,
                                "observations.is_collection_location IS TRUE",
                                "observations.is_collection_location IS FALSE"
                               )
    initialize_model_do_boolean(:has_location,
                                "observations.location_id IS NOT NULL",
                                "observations.location_id IS NULL"
                               )
    unless params[:has_name].nil?
      id = Name.unknown.id
      initialize_model_do_boolean(:has_name,
                                  "observations.name_id != #{id}",
                                  "observations.name_id == #{id}")
    end
    initialize_model_do_boolean(:has_notes,
                                'LENGTH(COALESCE(observations.notes,"")) > 0',
                                'LENGTH(COALESCE(observations.notes,"")) = 0'
                               )
    initialize_model_do_boolean(:has_votes,
                                "observations.vote_cache IS NOT NULL",
                                "observations.vote_cache IS NULL"
                               )
    add_join(:comments) if params[:has_comments]
    unless params[:comments_has].blank?
      initialize_model_do_search(:comments_has,
                                 "CONCAT(comments.summary,comments.notes)")
      add_join(:comments)
    end
    initialize_model_do_bounding_box(:observation)
    initialize_observation_filters
  end

  def initialize_project
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    add_join(:images_projects) if params[:has_images]
    add_join(:observations_projects) if params[:has_observations]
    add_join(:projects_species_lists) if params[:has_species_lists]
    initialize_model_do_search(:title_has, :title)
    initialize_model_do_search(:notes_has, :notes)
    initialize_model_do_boolean(:has_notes,
                                'LENGTH(COALESCE(species_lists.notes,"")) > 0',
                                'LENGTH(COALESCE(species_lists.notes,"")) = 0'
                               )
    add_join(:comments) if params[:has_comments]
    unless params[:comments_has].blank?
      initialize_model_do_search(:comments_has,
                                 "CONCAT(comments.summary,comments.notes)")
      add_join(:comments)
    end
  end

  def initialize_rss_log
    initialize_model_do_time(:updated_at)
  end

  def initialize_species_list
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_date(:date, :when)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_objects_by_name(Name, :names,
                                        "observations.name_id",
                                        join: { observations_species_lists: :observations }
                                       )
    initialize_model_do_objects_by_name(Name, :synonym_names,
                                        "observations.name_id", filter: :synonyms,
                                                                join: { observations_species_lists: :observations }
                                       )
    initialize_model_do_objects_by_name(Name, :children_names,
                                        "observations.name_id", filter: :all_children,
                                                                join: { observations_species_lists: :observations }
                                       )
    initialize_model_do_locations
    initialize_model_do_objects_by_name(
      Project, :projects, "projects_species_lists.project_id",
      join: :projects_species_lists
    )
    initialize_model_do_search(:title_has, :title)
    initialize_model_do_search(:notes_has, :notes)
    initialize_model_do_boolean(:has_notes,
                                'LENGTH(COALESCE(species_lists.notes,"")) > 0',
                                'LENGTH(COALESCE(species_lists.notes,"")) = 0'
                               )
    add_join(:comments) if params[:has_comments]
    unless params[:comments_has].blank?
      initialize_model_do_search(:comments_has,
                                 "CONCAT(comments.summary,comments.notes)")
      add_join(:comments)
    end
  end

  def initialize_user
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
  end

  # -------------------------------
  #  Model customization helpers.
  # -------------------------------

  def initialize_model_do_boolean(arg, true_cond, false_cond)
    where << (params[arg] ? true_cond : false_cond) unless params[arg].nil?
  end

  def initialize_model_do_search(arg, col = nil)
    unless params[arg].blank?
      col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
      search = google_parse(params[arg])
      self.where += google_conditions(search, col)
    end
  end

  def initialize_model_do_range(arg, col, args = {})
    if params[arg].is_a?(Array)
      min, max = params[arg]
      self.where << "#{col} >= #{min}" unless min.blank?
      self.where << "#{col} <= #{max}" unless max.blank?
      if (join = args[:join]) &&
         (!min.blank? || !max.blank?)
        # TODO: is this used? convert to piecewise add_join
        self.join << join
      end
    end
  end

  def initialize_model_do_enum_set(arg, col, vals, type)
    unless params[arg].blank?
      col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
      types = params[arg].to_s.strip_squeeze.split
      if type == :string
        types &= vals.map(&:to_s)
        self.where << "#{col} IN ('#{types.join("','")}')" if types.any?
      elsif
        types.map! { |v| vals.index_of(v.to_sym) }.reject!(&:nil?)
        self.where << "#{col} IN (#{types.join(",")})" if types.any?
      end
    end
  end

  def initialize_model_do_deprecated
    case params[:deprecated] || :either
    when :no then self.where << "names.deprecated IS FALSE"
    when :only then self.where << "names.deprecated IS TRUE"
    end
  end

  def initialize_model_do_misspellings
    case params[:misspellings] || :no
    when :no then self.where << "names.correct_spelling_id IS NULL"
    when :only then self.where << "names.correct_spelling_id IS NOT NULL"
    end
  end

  def initialize_model_do_objects_by_id(arg, col = nil)
    if ids = params[arg]
      col ||= "#{arg.to_s.sub(/s$/, "")}_id"
      col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
      set = clean_id_set(ids)
      self.where << "#{col} IN (#{set})"
    end
  end

  def initialize_model_do_objects_by_name(model, arg, col = nil, args = {})
    names = params[arg]
    if names && names.any?
      col ||= arg.to_s.sub(/s?$/, "_id")
      col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
      objs = []
      for name in names
        if name.to_s.match(/^\d+$/)
          obj = model.safe_find(name)
          objs << obj if obj
        else
          case model.name
          when "Location"
            pattern = clean_pattern(Location.clean_name(name))
            #            objs += model.all(:conditions => "name LIKE '%#{pattern}%'") # Rails 3
            objs += model.where("name LIKE ?", "%#{pattern}%")
          when "Name"
            if parse = Name.parse_name(name)
              name2 = parse.search_name
            else
              name2 = Name.clean_incoming_string(name)
            end
            matches = model.where(search_name: name2)
            matches = model.where(text_name: name2) if matches.empty?
            objs += matches
          when "Project", "SpeciesList"
            objs += model.where(title: name)
          when "User"
            name.sub(/ *<.*>/, "")
            objs += model.where(login: name)
          else
            fail("Forgot to tell initialize_model_do_objects_by_name how " \
                  "to find instances of #{model.name}!")
          end
        end
      end
      if filter = args[:filter]
        objs = objs.uniq.map(&filter).flatten
      end
      if join = args[:join]
        # TODO: is this used? convert to piecewise add_join
        self.join << join
      end
      set = clean_id_set(objs.map(&:id).uniq)
      self.where << "#{col} IN (#{set})"
    end
  end

  def initialize_model_do_locations(table = model_class.table_name, args = {})
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

  def initialize_model_do_bounding_box(type)
    if params[:north]
      n, s, e, w = params.values_at(:north, :south, :east, :west)
      if w < e
        cond1 = [
          "observations.lat >= #{s}",
          "observations.lat <= #{n}",
          "observations.long >= #{w}",
          "observations.long <= #{e}"
        ]
        cond2 = [
          "locations.south >= #{s}",
          "locations.north <= #{n}",
          "locations.west >= #{w}",
          "locations.east <= #{e}",
          "locations.west <= locations.east"
        ]
      else
        cond1 = [
          "observations.lat >= #{s}",
          "observations.lat <= #{n}",
          "(observations.long >= #{w} OR observations.long <= #{e})"
        ]
        cond2 = [
          "locations.south >= #{s}",
          "locations.north <= #{n}",
          "locations.west >= #{w}",
          "locations.east <= #{e}",
          "locations.west > locations.east"
        ]
      end
      if type == :location
        self.where += cond2
      else
        # Condition which returns true if the observation's lat/long is plausible.
        # (should be identical to BoxMethods.lat_long_close?)
        cond0 = %(
          observations.lat >= locations.south * 1.2 - locations.north * 0.2 AND
          observations.lat <= locations.north * 1.2 - locations.south * 0.2 AND
          if(locations.west <= locations.east,
            observations.long >= locations.west * 1.2 - locations.east * 0.2 AND
            observations.long <= locations.east * 1.2 - locations.west * 0.2,
            observations.long >= locations.west * 0.8 + locations.east * 0.2 + 72 OR
            observations.long <= locations.east * 0.8 + locations.west * 0.2 - 72
          )
        )
        cond1 = cond1.join(" AND ")
        cond2 = cond2.join(" AND ")
        # TODO: not sure how to deal with the bang notation -- indicates LEFT
        # OUTER JOIN instead of normal INNER JOIN.
        join << :"locations!" unless uses_join?(:locations)
        self.where << "IF(locations.id IS NULL OR #{cond0}, #{cond1}, #{cond2})"
      end
    end
  end

  def initialize_model_do_rank
    unless params[:rank].blank?
      min, max = params[:rank]
      max ||= min
      all_ranks = Name.all_ranks
      a = all_ranks.index(min) || 0
      b = all_ranks.index(max) || (all_ranks.length - 1)
      a, b = b, a if a > b
      ranks = all_ranks[a..b].map { |r| Name.ranks[r] }
      self.where << "names.rank IN (#{ranks.join(",")})"
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
    unless params[:content_types].blank?
      exts  = Image.all_extensions.map(&:to_s)
      mimes = Image.all_content_types.map(&:to_s) - [""]
      types = params[:types].to_s.strip_squeeze.split & exts
      if types.any?
        other = types.include?("raw")
        types -= ["raw"]
        types = types.map { |x| mimes[exts.index(x)] }
        str1 = "comments.target_type IN ('#{types.join("','")}')"
        str2 = "comments.target_type NOT IN ('#{mimes.join("','")}')"
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
    unless params[:license].blank?
      license = find_cached_parameter_instance(License, :license)
      self.where << "#{model_class.table_name}.license_id = #{license.id}"
    end
  end

  # ----------------------------
  #  Date customization.
  # ----------------------------

  def initialize_model_do_date(arg = :date, col = arg)
    col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
    if vals = params[arg]
      # Ugh, special case for search by month/day where range of months wraps around from December to January.
      if vals[0].to_s.match(/^\d\d-\d\d$/) &&
         vals[1].to_s.match(/^\d\d-\d\d$/) &&
         vals[0].to_s > vals[1].to_s
        m1, d1 = vals[0].to_s.split("-")
        m2, d2 = vals[1].to_s.split("-")
        self.where << "MONTH(#{col}) > #{m1} OR MONTH(#{col}) < #{m2} OR " \
                      "(MONTH(#{col}) = #{m1} AND DAY(#{col}) >= #{d1}) OR " \
                      "(MONTH(#{col}) = #{m2} AND DAY(#{col}) <= #{d2})"
      else
        initialize_model_do_date_half(true, vals[0], col)
        initialize_model_do_date_half(false, vals[1], col)
      end
    end
  end

  def initialize_model_do_date_half(min, val, col)
    dir = min ? ">" : "<"
    if val.to_s.match(/^\d\d\d\d/)
      y, m, d = val.split("-")
      m ||= min ? 1 : 12
      d ||= min ? 1 : 31
      self.where << "#{col} #{dir}= '%04d-%02d-%02d'" % [y, m, d].map(&:to_i)
    elsif val.to_s.match(/-/)
      m, d = val.split("-")
      self.where << "MONTH(#{col}) #{dir} #{m} OR " \
                    "(MONTH(#{col}) = #{m} AND " \
                    "DAY(#{col}) #{dir}= #{d})"
    elsif !val.blank?
      self.where << "MONTH(#{col}) #{dir}= #{val}"
      # XXX This fails if start month > end month XXX
    end
  end

  def initialize_model_do_time(arg = :time, col = arg)
    col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
    if vals = params[arg]
      initialize_model_do_time_half(true, vals[0], col)
      initialize_model_do_time_half(false, vals[1], col)
    end
  end

  def initialize_model_do_time_half(min, val, col)
    unless val.blank?
      dir = min ? ">" : "<"
      y, m, d, h, n, s = val.split("-")
      m ||= min ? 1 : 12
      d ||= min ? 1 : 31
      h ||= min ? 0 : 24
      n ||= min ? 0 : 60
      s ||= min ? 0 : 60
      self.where << "#{col} #{dir}= '%04d-%02d-%02d %02d:%02d:%02d'" %
        [y, m, d, h, n, s].map(&:to_i)
    end
  end

  def validate_name(arg, val)
    if val.is_a?(Name)
      fail("Value for :#{arg} is an unsaved Name instance.") unless val.id
      @params_cache ||= {}
      @params_cache[arg] = val
      val.id
    elsif val.is_a?(String)
      val
    elsif val.is_a?(Fixnum)
      val
    else
      fail("Value for :#{arg} should be a Name, String or Fixnum, got: #{val.class}")
    end
  end

  def validate_date(arg, val)
    if val.acts_like?(:date)
      "%04d-%02d-%02d" % [val.year, val.mon, val.day]
    elsif val.to_s.match(/^\d\d\d\d(-\d\d?){0,2}$/i)
      val
    elsif val.to_s.match(/^\d\d?(-\d\d?)?$/i)
      val
    elsif val.blank? || val.to_s == "0"
      nil
    else
      fail("Value for :#{arg} should be a date (YYYY-MM-DD or MM-DD), got: #{val.inspect}")
    end
  end

  def validate_time(arg, val)
    if val.acts_like?(:time)
      val = val.in_time_zone
      "%04d-%02d-%02d-%02d-%02d-%02d" %
        [val.year, val.mon, val.day, val.hour, val.min, val.sec]
    elsif val.to_s.match(/^\d\d\d\d(-\d\d?){0,5}$/i)
      val
    elsif val.blank? || val.to_s == "0"
      nil
    else
      fail("Value for :#{arg} should be a time (YYYY-MM-DD-HH-MM-SS), got: #{val.inspect}")
    end
  end

  # --------------------------------------------
  #  Queries that essentially have no filters.
  # --------------------------------------------

  def initialize_all
    if (by = params[:by]) &&
       (by = :"sort_by_#{by}")
      title_args[:tag] ||= :query_title_all_by
      title_args[:order] = by.t
    end

    # Allow users to filter RSS logs for the object type they're interested in.
    if model_symbol == :RssLog
      x = params[:type] ||= "all"
      types = x.to_s.split
      unless types.include?("all")
        types &= RssLog.all_types
        if types.empty?
          self.where << "FALSE"
        else
          self.where << types.map do |type|
            "rss_logs.#{type}_id IS NOT NULL"
          end.join(" OR ")
        end
      end
    elsif params[:type]
      fail "Can't use :type parameter in :#{model_symbol} :all queries!"
    end
  end

  def initialize_by_rss_log
    add_join(:rss_logs)
    params[:by] ||= "rss_log"
  end

  # ----------------------------
  #  Get user contributions.
  # ----------------------------

  def initialize_by_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    table = model_class.table_name
    if model_class.column_names.include?("user_id")
      self.where << "#{table}.user_id = '#{params[:user]}'"
    else
      fail "Can't figure out how to select #{model_string} by user_id!"
    end
    case model_symbol
    when :Observation
      params[:by] ||= "updated_at"
    when :Image
      params[:by] ||= "updated_at"
    when :Location, :Name, :LocationDescription, :NameDescription
      params[:by] ||= "name"
    when :SpeciesList
      params[:by] ||= "title"
    when :Comment
      params[:by] ||= "created_at"
    end
  end

  def initialize_for_project
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    join_table = [model_class.table_name, "projects"].sort.join("_")
    self.where << "#{join_table}.project_id = '#{params[:project]}'"
    add_join(join_table)
  end

  def initialize_for_target
    type = begin
             params[:type].to_s.constantize
           rescue
             nil
           end
    if begin
          !type.reflect_on_association(:comments)
        rescue
          true
        end
      fail "The model #{params[:type].inspect} does not support comments!"
    end
    target = find_cached_parameter_instance(type, :target)
    title_args[:object] = target.unique_format_name
    self.where << "comments.target_id = '#{target.id}'"
    self.where << "comments.target_type = '#{type.name}'"
    params[:by] ||= "created_at"
  end

  def initialize_for_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:observations)
    self.where << "observations.user_id = '#{params[:user]}'"
    params[:by] ||= "created_at"
  end

  def initialize_by_author
    initialize_by_editor
  end

  def initialize_by_editor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    case model_symbol
    when :Name, :Location
      version_table = "#{model_class.table_name}_versions".to_sym
      add_join(version_table)
      self.where << "#{version_table}.user_id = '#{params[:user]}'"
      self.where << "#{model_class.table_name}.user_id != '#{params[:user]}'"
    when :NameDescription, :LocationDescription
      glue_table = "#{model_string.underscore}s_#{flavor}s".
                   sub("_by_", "_").to_sym
      add_join(glue_table)
      self.where << "#{glue_table}.user_id = '#{params[:user]}'"
      params[:by] ||= "name"
    else
      fail "No editors or authors in #{model_string}!"
    end
  end

  # -----------------------------------
  #  Various subsets of Observations.
  # -----------------------------------

  def initialize_at_location
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    add_join(:names)
    self.where << "#{model_class.table_name}.location_id = '#{params[:location]}'"
    params[:by] ||= "name"
  end

  def initialize_at_where
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    add_join(:names)
    self.where << "#{model_class.table_name}.where LIKE '%#{pattern}%'"
    params[:by] ||= "name"
  end

  def initialize_in_species_list
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    add_join(:names)
    add_join(:observations_species_lists)
    self.where << "observations_species_lists.species_list_id = '#{params[:species_list]}'"
    params[:by] ||= "name"
  end

  # ----------------------------------
  #  Queryies dealing with synonyms.
  # ----------------------------------

  def initialize_of_name
    extra_joins = []

    if name = get_cached_parameter_instance(:name)
      names = [name]
    else
      name = params[:name]
      if name.is_a?(Fixnum) || name.match(/^\d+$/)
        names = [Name.find(name.to_i)]
      else
        names = Name.where(search_name: name)
        names = Name.where(text_name: name) if names.empty?
      end
    end

    synonyms     = params[:synonyms] || :no
    nonconsensus = params[:nonconsensus] || :no

    title_args[:tag] = :query_title_of_name
    title_args[:tag] = :query_title_of_name_synonym      if synonyms != :no
    title_args[:tag] = :query_title_of_name_nonconsensus if nonconsensus != :no
    title_args[:name] = names.length == 1 ? names.first.display_name : params[:name]

    if synonyms == :no
      name_ids = names.map(&:id) + names.map(&:misspelling_ids).flatten
    elsif synonyms == :all
      name_ids = names.map(&:synonym_ids).flatten
    elsif synonyms == :exclusive
      name_ids = names.map(&:synonym_ids).flatten - names.map(&:id) - names.map(&:misspelling_ids).flatten
    else
      fail "Invalid synonym inclusion mode: '#{synonyms}'"
    end
    set = clean_id_set(name_ids.uniq)

    if nonconsensus == :no
      self.where << "observations.name_id IN (#{set}) AND " \
                    "COALESCE(observations.vote_cache,0) >= 0"
      self.order = "COALESCE(observations.vote_cache,0) DESC, observations.when DESC"
    elsif nonconsensus == :all
      self.where << "namings.name_id IN (#{set})"
      self.order = "COALESCE(namings.vote_cache,0) DESC, observations.when DESC"
      extra_joins << :namings
    elsif nonconsensus == :exclusive
      self.where << "namings.name_id IN (#{set}) AND " \
                    "(observations.name_id NOT IN (#{set}) OR " \
                    "COALESCE(observations.vote_cache,0) < 0)"
      self.order = "COALESCE(namings.vote_cache,0) DESC, observations.when DESC"
      extra_joins << :namings
    else
      fail "Invalid nonconsensus inclusion mode: '#{nonconsensus}'"
    end

    # Allow restriction to one project, species_list or user.
    if params[:project]
      project = find_cached_parameter_instance(Project, :project)
      self.where << "observations_projects.project_id = #{project.id}"
      extra_joins << :observations_projects
    end
    if params[:species_list]
      species_list = find_cached_parameter_instance(SpeciesList, :species_list)
      self.where << "observations_species_lists.species_list_id = #{species_list.id}"
      extra_joins << :observations_species_lists
    end
    if params[:user]
      user = find_cached_parameter_instance(User, :user)
      self.where << "observations.user_id = #{user.id}"
    end

    # Different join conditions for different models.
    if model_symbol == :Observation
      extra_joins.each { |table| add_join(table) }
    elsif model_symbol == :Location
      add_join(:observations)
      extra_joins.each { |table| add_join(:observations, table) }
      self.where << "observations.is_collection_location IS TRUE"
    elsif model_symbol == :Image
      add_join(:images_observations, :observations)
      extra_joins.each { |table| add_join(:observations, table) }
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
    params[:by] ||= "name"

    # If we have to rely on classification strings, just let Name do it, and
    # create a pseudo-query based on ids returned by +name.children+.
    if all || !name.at_or_below_genus?
      set = clean_id_set(name.children(all).map(&:id))
      self.where << "names.id IN (#{set})"

    # If at genus or below, we can deduce hierarchy purely by syntax.
    else
      self.where << "names.text_name LIKE '#{name.text_name} %'"
      unless all
        if name.rank == :Genus
          self.where << "names.text_name NOT LIKE '#{name.text_name} % %'"
        else
          self.where << "names.text_name NOT LIKE '#{name.text_name} % % %'"
        end
      end
    end

    # Add appropriate joins.
    if model_symbol == :Observation
      add_join(:names)
    elsif model_symbol == :Image
      add_join(:images_observations, :observations)
      add_join(:observations, :names)
    elsif model_symbol == :Location
      add_join(:observations, :names)
    end
  end

  def initialize_of_parents
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    all = params[:all] || false
    set = clean_id_set(name.parents(all).map(&:id))
    self.where << "names.id IN (#{set})"
    params[:by] ||= "name"
  end

  # ---------------------------------------------------------------------
  #  Coercable image/location/name queries based on observation-related
  #  conditions.
  # ---------------------------------------------------------------------

  def initialize_with_observations
    if model_symbol == :Image
      add_join(:images_observations, :observations)
    else
      add_join(:observations)
    end
    params[:by] ||= "name"
    initialize_observation_filters
  end

  def initialize_with_observations_at_location
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    if model_symbol == :Image
      add_join(:images_observations, :observations)
    else
      add_join(:observations)
    end
    self.where << "observations.location_id = '#{params[:location]}'"
    self.where << "observations.is_collection_location IS TRUE"
    params[:by] ||= "name"
    initialize_observation_filters
  end

  def initialize_with_observations_at_where
    location = params[:location]
    title_args[:where] = location
    if model_symbol == :Image
      add_join(:images_observations, :observations)
    else
      add_join(:observations)
    end
    self.where << "observations.where LIKE '%#{clean_pattern(location)}%'"
    self.where << "observations.is_collection_location IS TRUE"
    params[:by] ||= "name"
    initialize_observation_filters
  end

  def initialize_with_observations_by_user
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    if model_symbol == :Image
      add_join(:images_observations, :observations)
    else
      add_join(:observations)
    end
    self.where << "observations.user_id = '#{params[:user]}'"
    if model_symbol == :Location
      self.where << "observations.is_collection_location IS TRUE"
    end
    params[:by] ||= "name"
    initialize_observation_filters
  end

  def initialize_with_observations_for_project
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    if model_symbol == :Image
      add_join(:images_observations, :observations)
      add_join(:observations, :observations_projects)
    else
      add_join(:observations, :observations_projects)
    end
    self.where << "observations_projects.project_id = '#{params[:project]}'"
    if model_symbol == :Location
      self.where << "observations.is_collection_location IS TRUE"
    end
    params[:by] ||= "name"
    initialize_observation_filters
  end

  def initialize_with_observations_in_set
    title_args[:observations] = params[:old_title] ||
                                :query_title_in_set.t(type: :observation)
    set = clean_id_set(params[:ids])
    if model_symbol == :Image
      add_join(:images_observations, :observations)
    else
      add_join(:observations)
    end
    self.where << "observations.id IN (#{set})"
    if model_symbol == :Location
      self.where << "observations.is_collection_location IS TRUE"
    end
    params[:by] ||= "name"
    initialize_observation_filters
  end

  def initialize_with_observations_in_species_list
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    if model_symbol == :Image
      add_join(:images_observations, :observations)
      add_join(:observations, :observations_species_lists)
    else
      add_join(:observations, :observations_species_lists)
    end
    self.where << "observations_species_lists.species_list_id = '#{params[:species_list]}'"
    if model_symbol == :Location
      self.where << "observations.is_collection_location IS TRUE"
    end
    params[:by] ||= "name"
    initialize_observation_filters
  end

  def initialize_with_observations_of_children
    initialize_of_children
    initialize_observation_filters
  end

  def initialize_with_observations_of_name
    initialize_of_name
    title_args[:tag] = title_args[:tag].to_s.sub("title", "title_with_observations").to_sym
    initialize_observation_filters
  end

  # Used for all observation queries, and for all observation queries which
  # have been coerced into other models' queries.
  def initialize_observation_filters
    initialize_model_do_boolean(:has_specimen,
                                "observations.specimen IS TRUE",
                                "observations.specimen IS FALSE"
                               )
    initialize_model_do_boolean(:has_images,
                                "observations.thumb_image_id IS NOT NULL",
                                "observations.thumb_image_id IS NULL"
                               )
    if params[:has_obs_tag]
      # TODO: no way to join on existing triples table!
      # join.add_leaf(:observations, :triple_glue.observation)
    end
    if params[:has_name_tag]
      # TODO: no way to join on existing triples table!
      # join.add_leaf(:observations, :triple_glue.name)
    end
  end

  # ---------------------------------------------------------------
  #  Coercable location/name queries based on description-related
  #  conditions.
  # ---------------------------------------------------------------

  def initialize_with_descriptions
    type = model_string.underscore
    add_join(:"#{type}_descriptions")
    params[:by] ||= "name"
  end

  def initialize_with_descriptions_by_author
    initialize_with_descriptions_by_editor
  end

  def initialize_with_descriptions_by_editor
    type = model_string.underscore
    glue = flavor.to_s.sub(/^.*_by_/, "")
    desc_table = :"#{type}_descriptions"
    glue_table = :"#{type}_descriptions_#{glue}s"
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(desc_table, glue_table)
    self.where << "#{glue_table}.user_id = '#{params[:user]}'"
    params[:by] ||= "name"
  end

  def initialize_with_descriptions_by_user
    type = model_string.underscore
    desc_table = :"#{type}_descriptions"
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(desc_table)
    self.where << "#{desc_table}.user_id = '#{params[:user]}'"
    params[:by] ||= "name"
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

    when :Herbarium
      self.where += google_conditions(search,
                                      'CONCAT(herbaria.name,COALESCE(herbaria.description,""),COALESCE(herbaria.mailing_address,""))')

    when :Image
      add_join(:images_observations, :observations)
      add_join(:observations, :locations!)
      add_join(:observations, :names)
      self.where += google_conditions(search,
                                      'CONCAT(names.search_name,COALESCE(images.original_name,""),' \
                                      'COALESCE(images.copyright_holder,""),COALESCE(images.notes,""),' \
                                      "IF(locations.id,locations.name,observations.where))")

    when :Location
      add_join(:"location_descriptions.default!")
      note_fields = LocationDescription.all_note_fields.map do |x|
        "COALESCE(location_descriptions.#{x},'')"
      end
      self.where += google_conditions(search,
                                      "CONCAT(locations.name,#{note_fields.join(",")})")

    when :Name
      add_join(:"name_descriptions.default!")
      note_fields = NameDescription.all_note_fields.map do |x|
        "COALESCE(name_descriptions.#{x},'')"
      end
      self.where += google_conditions(search,
                                      "CONCAT(names.search_name,COALESCE(names.citation,'')," \
                                              "COALESCE(names.notes,''),#{note_fields.join(",")})")

    when :Observation
      add_join(:locations!)
      add_join(:names)
      self.where += google_conditions(search,
                                      'CONCAT(names.search_name,COALESCE(observations.notes,""),' \
                                      "IF(locations.id,locations.name,observations.where))")

    when :Project
      self.where += google_conditions(search,
                                      'CONCAT(projects.title,COALESCE(projects.summary,""))')

    when :SpeciesList
      add_join(:locations!)
      self.where += google_conditions(search,
                                      'CONCAT(species_lists.title,COALESCE(species_lists.notes,""),' \
                                      "IF(locations.id,locations.name,species_lists.where))")

    when :Specimen
      self.where += google_conditions(search,
                                      'CONCAT(specimens.herbarium_label,COALESCE(specimens.notes,""))')

    when :User
      self.where += google_conditions(search,
                                      "CONCAT(users.login,users.name)")

    else
      fail "Forgot to tell me how to build a :#{flavor} query for #{model}!"
    end
  end

  # ----------------------------
  #  Regexp search.
  # ----------------------------

  def initialize_regexp_search
    regexp = params[:regexp].to_s.strip_squeeze

    case model_symbol

    when :Location
      self.where += ["locations.name REGEXP '#{Location.connection.quote_string(regexp)}'"]

    else
      fail "Forgot to tell me how to build a :#{flavor} query for #{model}!"
    end
  end

  # ----------------------------
  #  Advanced search.
  # ----------------------------

  def initialize_advanced_search
    name     = google_parse(params[:name])
    user     = google_parse(params[:user].to_s.gsub(/ *<[^<>]*>/, ""))
    location = google_parse(params[:location])
    content  = google_parse(params[:content])

    # Force user to enter *something*.
    if name.blank? && user.blank? && location.blank? && content.blank?
      fail :runtime_no_conditions.t
    end

    # This case is a disaster.  Perform it as an observation query, then
    # coerce into images.
    if (model_symbol == :Image) && !content.blank?
      self.executor = lambda do |args|
        args2 = args.dup
        args2.delete(:select)
        params2 = params.dup
        params2.delete(:by)
        ids = self.class.lookup(:Observation, flavor, params2).result_ids(args2)
        ids = clean_id_set(ids)
        args2 = args.dup
        extend_join(args2) << :images_observations
        extend_where(args2) << "images_observations.observation_id IN (#{ids})"
        model_class.connection.select_rows(query(args2))
      end
      return
    end

    case model_symbol
    when :Image
      add_join(:images_observations, :observations) unless [user, name, location, content].all?(&:blank?)
      add_join(:observations, :users)      unless user.blank?
      add_join(:observations, :names)      unless name.blank?
      add_join(:observations, :locations!) unless location.blank?
    when :Location
      add_join(:observations, :users) unless user.blank?
      add_join(:observations, :names) unless name.blank?
      add_join(:observations)         unless content.blank?
    when :Name
      add_join(:observations, :users)      unless user.blank?
      add_join(:observations, :locations!) unless location.blank?
      add_join(:observations)              unless content.blank?
    when :Observation
      add_join(:names)      unless name.blank?
      add_join(:users)      unless user.blank?
      add_join(:locations!) unless location.blank?
    end

    # Name of mushroom...
    self.where += google_conditions(name, "names.search_name") unless name.blank?

    # Who observed the mushroom...
    unless user.blank?
      self.where += google_conditions(user, "CONCAT(users.login,users.name)")
    end

    # Where the mushroom was seen...
    unless location.blank?
      if model_symbol == :Location
        self.where += google_conditions(location, "locations.name")
      elsif params[:search_location_notes]
        self.where += google_conditions(location,
                                        "IF(locations.id,CONCAT(locations.name,locations.notes),observations.where)")
      else
        self.where += google_conditions(location,
                                        "IF(locations.id,locations.name,observations.where)")
      end
    end

    # Content of observation and comments...
    unless content.blank?

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
        args2[:where] += google_conditions(content, "observations.notes")
        results = model_class.connection.select_rows(query(args2))

        args2 = args.dup
        extend_join(args2) << case model_symbol
                              when :Image then { images_observations: { observations: :comments } }
                              when :Location then { observations: :comments }
                              when :Name then { observations: :comments }
                              when :Observation then :comments
        end
        extend_where(args2)
        args2[:where] += google_conditions(content,
                                           "CONCAT(observations.notes,comments.summary,comments.comment)")
        results |= model_class.connection.select_rows(query(args2))
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
