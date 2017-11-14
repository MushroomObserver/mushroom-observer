class API
  # API for Location
  class LocationAPI < ModelAPI
    self.model = Location

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :comments
    ]

    def query_params
      {
        where:      sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        users:      parse_array(:user, :user),
        north:      parse(:latitude, :north),
        south:      parse(:latitude, :south),
        east:       parse(:longitude, :east),
        west:       parse(:longitude, :west)
      }
    end

    def create_params
      {
        display_name: parse(:string, :name, limit: 1024),
        north:        parse(:latitude, :north),
        south:        parse(:longitude, :south),
        east:         parse(:longitude, :east),
        west:         parse(:longitude, :west),
        high:         parse(:altitude, :high, default: nil),
        low:          parse(:altitude, :low, default: nil),
        notes:        parse(:string, :notes, default: "")
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:name)  unless params[:name]
      raise MissingParameter.new(:north) unless params[:north]
      raise MissingParameter.new(:south) unless params[:south]
      raise MissingParameter.new(:east)  unless params[:east]
      raise MissingParameter.new(:west)  unless params[:west]
      make_sure_location_doesnt_exist!(params)
    end

    def make_sure_location_doesnt_exist!(params)
      name = params[:display_name].to_s
      return unless Location.find_by_name_or_reverse_name(name)
      raise LocationAlreadyExists.new(name)
    end

    def update_params
      validate_new_location_name!
      {
        display_name: name,
        north:        parse(:latitude, :set_north),
        south:        parse(:longitude, :set_south),
        east:         parse(:longitude, :set_east),
        west:         parse(:longitude, :set_west),
        high:         parse(:altitude, :set_high),
        low:          parse(:altitude, :set_low),
        notes:        parse(:string, :set_notes)
      }
    end

    def validate_new_location_name!
      name = parse(:string, :set_name, limit: 1024)
      return if name.blank?
      already_exists   = Location.find_by_name_or_reverse_name(name)
      multiple_matches = query.num_results > 1
      raise LocationAlreadyExists.new(name)            if already_exists
      raise TryingToSetMultipleLocationsToSameName.new if multiple_matches
    end

    def must_have_edit_permission!(_obj); end

    def delete
      raise NoMethodForAction.new("DELETE", action)
    end
  end
end
