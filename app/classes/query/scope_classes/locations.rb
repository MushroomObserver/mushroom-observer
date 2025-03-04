# frozen_string_literal: true

class Query::ScopeClasses::Locations < Query::BaseAR
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::ScopeInitializers::AdvancedSearch
  include Query::ScopeInitializers::Filters
  include Query::Titles::Observations

  def model
    Location
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Location],
      by_users: [User],
      by_editor: User,
      in_box: { north: :float, south: :float, east: :float, west: :float },
      pattern: :string,
      regexp: :string,
      has_notes: :boolean,
      notes_has: :string,
      has_descriptions: :boolean,
      has_observations: :boolean,
      description_query: { subquery: :LocationDescription },
      observation_query: { subquery: :Observation }
    ).merge(content_filter_parameter_declarations(Location)).
      merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    initialize_locations_has_descriptions
    initialize_locations_has_observations
    initialize_locations_only_parameters
    add_bounding_box_conditions_for_locations
    initialize_subquery_parameters
    initialize_content_filters(Location)
    super
  end

  def add_regexp_condition
    return if params[:regexp].blank?

    regexp = escape(params[:regexp].to_s.strip_squeeze)
    # where << "locations.name REGEXP #{regexp}"
    @scopes = @scopes.where(Location[:name] =~ regexp)

    @title_tag = :query_title_regexp_search
  end
end
