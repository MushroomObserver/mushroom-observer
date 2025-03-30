# frozen_string_literal: true

class Query::SpeciesLists < Query::Base
  def model
    @model ||= SpeciesList
  end

  def list_by
    @list_by ||= case params[:order_by].to_s
                 when "user", "reverse_user"
                   User[:login]
                 else
                   SpeciesList[:title]
                 end
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      date: [:date],
      id_in_set: [SpeciesList],
      by_users: [User],
      title_has: :string,
      has_notes: :boolean,
      notes_has: :string,
      has_comments: { boolean: [true] },
      comments_has: :string,
      search_where: :string,
      locations: [Location],
      projects: [Project],
      pattern: :string,
      observation_query: { subquery: :Observation }
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions
    add_date_condition("species_lists.when", params[:date])
    add_pattern_condition
    add_id_in_set_condition
    add_subquery_condition(:observation_query, :species_list_observations,
                           table: :species_list_observations,
                           col: :observation_id)
    initialize_association_parameters
    initialize_boolean_parameters
    initialize_at_where_parameter
    initialize_search_parameters
    super
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_search_condition(search_fields, params[:pattern])
    add_join(:locations!)
    super
  end

  def initialize_association_parameters
    initialize_locations_parameter(:species_lists, params[:locations])
    initialize_projects_parameter(:project_species_lists,
                                  [:project_species_lists])
  end

  def initialize_boolean_parameters
    add_boolean_condition(
      "LENGTH(COALESCE(species_lists.notes,'')) > 0",
      "LENGTH(COALESCE(species_lists.notes,'')) = 0",
      params[:has_notes]
    )
    add_join(:comments) if params[:has_comments]
  end

  def initialize_at_where_parameter
    return unless params[:search_where]

    location_str = params[:search_where]
    @where << "species_lists.where LIKE '%#{clean_pattern(location_str)}%'"
  end

  def initialize_search_parameters
    add_search_condition("species_lists.title", params[:title_has])
    add_search_condition("species_lists.notes", params[:notes_has])
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has],
      :comments
    )
  end

  def search_fields
    "CONCAT(" \
      "species_lists.title," \
      "COALESCE(species_lists.notes,'')," \
      "IF(locations.id,locations.name,species_lists.where)" \
      ")"
  end

  # Only instance methods have access to params.
  def default_order
    if params[:search_where].present? || params[:location].present?
      "name"
    else
      "title"
    end
  end

  def self.default_order
    "title"
  end
end
