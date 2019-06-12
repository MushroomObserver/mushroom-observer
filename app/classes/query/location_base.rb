module Query
  # Common code for all location queries.
  class LocationBase < Query::Base
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
        initialize_model_do_time(:created_at)
        initialize_model_do_time(:updated_at)
        initialize_model_do_objects_by_id(:users)
      end
      initialize_model_do_location_bounding_box
      initialize_content_filters(Location)
      super
    end

    def default_order
      "name"
    end
  end
end
