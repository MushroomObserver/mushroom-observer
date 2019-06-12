class Query::LocationBase < Query::Base
  include Query::Initializers::ContentFilters

  def model
    Location
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?:      [User],
      north?:      :float,
      south?:      :float,
      east?:       :float,
      west?:       :float
    ).merge(content_filter_parameter_declarations(Location))
  end

  def initialize_flavor
    unless is_a?(LocationWithObservations)
      add_owner_and_time_stamp_conditions("locations")
    end
    add_bounding_box_conditions_for_locations
    initialize_content_filters(Location)
    super
  end

  def default_order
    "name"
  end
end
