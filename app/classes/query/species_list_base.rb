class Query::SpeciesListBase < Query::Base
  def model
    SpeciesList
  end

  def parameter_declarations
    super.merge(
      created_at?:     [:time],
      updated_at?:     [:time],
      date?:           [:date],
      users?:          [User],
      names?:          [:string],
      synonym_names?:  [:string],
      children_names?: [:string],
      locations?:      [:string],
      projects?:       [:string],
      title_has?:      :string,
      has_notes?:      :boolean,
      notes_has?:      :string,
      has_comments?:   { boolean: [true] },
      comments_has?:   :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("species_lists")
    add_date_condition("species_lists.when", params[:date])
    initialize_names_parameter
    initialize_synonym_names_parameter
    initialize_children_names_parameter
    initialize_locations_parameter
    initialize_projects_parameter
    initialize_has_notes_parameter
    add_join(:comments) if params[:has_comments]
    add_search_condition("species_lists.title", params[:title_has])
    add_search_condition("species_lists.notes", params[:notes_has])
    initialize_comments_has_parameter
    super
  end

  def initialize_names_parameter
    add_id_condition(
      "observations.name_id",
      lookup_names_by_name(params[:names]),
      :observations_species_lists, :observations
    )
  end

  def initialize_synonym_names_parameter
    add_id_condition(
      "observations.name_id",
      lookup_names_by_name(params[:synonym_names], :synonyms),
      :observations_species_lists, :observations
    )
  end

  def initialize_children_names_parameter
    add_id_condition(
      "observations.name_id",
      lookup_names_by_name(params[:children_names], :all_children),
      :observations_species_lists, :observations
    )
  end

  def initialize_locations_parameter
    add_where_condition("species_lists", params[:locations])
  end

  def initialize_projects_parameter
    add_id_condition(
      "projects_species_lists.project_id",
      lookup_projects_by_name(params[:projects]),
      :projects_species_lists
    )
  end

  def initialize_has_notes_parameter
    add_boolean_condition(
      "LENGTH(COALESCE(species_lists.notes,'')) > 0",
      "LENGTH(COALESCE(species_lists.notes,'')) = 0",
      params[:has_notes]
    )
  end

  def initialize_comments_has_parameter
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has],
      :comments
    )
  end

  def default_order
    "title"
  end
end
