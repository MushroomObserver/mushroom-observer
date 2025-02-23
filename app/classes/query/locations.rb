# frozen_string_literal: true

class Query::Locations < Query::Base
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::AdvancedSearch
  include Query::Initializers::Filters
  include Query::Titles::Observations

  def model
    Location
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [Location],
      by_users: [User],
      by_editor: User,
      in_box: { north: :float, south: :float, east: :float, west: :float },
      pattern: :string,
      regexp: :string,
      with_notes: :boolean,
      notes_has: :string,
      with_descriptions: :boolean,
      with_observations: :boolean,
      description_query: { subquery: :LocationDescription },
      observation_query: { subquery: :Observation }
    ).merge(content_filter_parameter_declarations(Location)).
      merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    initialize_locations_with_descriptions
    initialize_locations_with_observations
    initialize_locations_only_parameters
    add_bounding_box_conditions_for_locations
    initialize_subquery_parameters
    initialize_content_filters(Location)
    super
  end

  def initialize_locations_with_descriptions
    return if params[:with_descriptions].blank?

    add_join(:location_descriptions)
  end

  def initialize_locations_with_observations
    return if params[:with_observations].blank?

    add_join(:observations)
  end

  def initialize_locations_only_parameters
    add_id_in_set_condition
    add_owner_and_time_stamp_conditions
    add_by_editor_condition
    initialize_location_notes_parameters
    add_regexp_condition
    add_pattern_condition
    add_advanced_search_conditions
  end

  def initialize_location_notes_parameters
    add_boolean_condition("LENGTH(COALESCE(locations.notes,'')) > 0",
                          "LENGTH(COALESCE(locations.notes,'')) = 0",
                          params[:with_notes])
    add_search_condition("locations.notes", params[:notes_has])
  end

  def add_regexp_condition
    return if params[:regexp].blank?

    @title_tag = :query_title_regexp_search
    regexp = escape(params[:regexp].to_s.strip_squeeze)
    where << "locations.name REGEXP #{regexp}"
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_join(:"location_descriptions.default!")
    super
  end

  def add_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    add_join(:observations) if params[:search_content].present?
    initialize_advanced_search
  end

  def initialize_subquery_parameters
    add_subquery_condition(:description_query, :location_descriptions)
    add_subquery_condition(:observation_query, :observations)
  end

  def add_join_to_names
    add_join(:observations, :names)
  end

  def add_join_to_users
    add_join(:observations, :users)
  end

  def add_join_to_locations; end

  def content_join_spec
    { observations: :comments }
  end

  def search_fields
    "CONCAT(" \
      "locations.name," \
      "#{LocationDescription.all_note_fields.map do |x|
           "COALESCE(location_descriptions.#{x},'')"
         end.join(",")}" \
    ")"
  end

  def self.default_order
    "name"
  end

  def title
    default = super
    if params[:with_observations] || params[:observation_query]
      with_observations_query_description || default
    elsif params[:with_descriptions] || params[:description_query]
      :query_title_with_descriptions.t(type: :location) || default
    else
      default
    end
  end
end
