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
        initialize_created_at_condition
        initialize_updated_at_condition
        initialize_users_condition
      end
      initialize_model_do_location_bounding_box
      initialize_content_filters(Location)
      super
    end

    def initialize_created_at_condition
      initialize_model_do_time(:created_at)
    end

    def initialize_updated_at_condition
      initialize_model_do_time(:updated_at)
    end

    def initialize_users_condition
      initialize_model_do_objects_by_id(:users)
    end

    def default_order
      "name"
    end
  end
end
