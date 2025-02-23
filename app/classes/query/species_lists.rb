# frozen_string_literal: true

class Query::SpeciesLists < Query::Base
  def model
    SpeciesList
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      date: [:date],
      ids: [SpeciesList],
      by_users: [User],
      locations: [Location],
      search_where: :string,
      projects: [Project],
      title_has: :string,
      with_notes: :boolean,
      notes_has: :string,
      with_comments: { boolean: [true] },
      comments_has: :string,
      pattern: :string,
      observation_query: { subquery: :Observation }
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_date_condition("species_lists.when", params[:date])
    add_pattern_condition
    add_ids_condition
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
      params[:with_notes]
    )
    add_join(:comments) if params[:with_comments]
  end

  def initialize_at_where_parameter
    return unless params[:search_where]

    location_str = params[:search_where]
    title_args[:where] = location_str
    where << "species_lists.where LIKE '%#{clean_pattern(location_str)}%'"
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
