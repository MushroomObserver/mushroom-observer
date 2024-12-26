# frozen_string_literal: true

class Query::LocationBase < Query::Base
  include Query::Initializers::Locations
  include Query::Initializers::Descriptions
  include Query::Initializers::ContentFilters
  include Query::Initializers::AdvancedSearch

  def model
    Location
  end

  def parameter_declarations
    super.merge(locations_only_parameter_declarations).
      merge(bounding_box_parameter_declarations).
      merge(content_filter_parameter_declarations(Location)).
      merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    unless is_a?(Query::LocationWithObservations) ||
           is_a?(Query::LocationWithDescriptions)
      add_ids_condition
      add_owner_and_time_stamp_conditions
      add_by_user_condition
      add_by_editor_condition
      add_pattern_condition
      add_regexp_condition
      add_advanced_search_conditions
    end
    add_bounding_box_conditions_for_locations
    initialize_content_filters(Location)
    super
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
end
