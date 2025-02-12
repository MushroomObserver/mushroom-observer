# frozen_string_literal: true

class Query::Locations < Query::Base
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::Locations
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
      by_user: User,
      by_editor: User,
      users: [User],
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
    add_ids_condition
    add_owner_and_time_stamp_conditions
    add_by_user_condition
    add_by_editor_condition
    initialize_location_notes_parameters
    add_pattern_condition
    add_regexp_condition
    add_advanced_search_conditions
  end

  def initialize_subquery_parameters
    add_subquery_condition(:description_query, :location_descriptions)
    add_subquery_condition(:observation_query, :observations)
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_join(:"location_descriptions.default!")
    super
  end

  def add_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    add_join(:observations) if params[:content].present?
    initialize_advanced_search
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

  # def coerce_into_location_description_query
  #   Query.lookup(:LocationDescription, params_back_to_description_params)
  # end

  def title
    default = super
    if params[:with_observations]
      with_observations_query_description || default
    elsif params[:with_descriptions]
      :query_title_with_descriptions.t(type: :location) || default
    else
      default
    end
  end
end
