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
      n, s, e, w = parse_bounding_box!
      {
        where:      sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        users:      parse_array(:user, :user),
        north:      n,
        south:      s,
        east:       e,
        west:       w
      }
    end

    def create_params
      {
        user:         @user,
        display_name: parse(:string, :name, limit: 1024),
        north:        parse(:latitude, :north),
        south:        parse(:longitude, :south),
        east:         parse(:longitude, :east),
        west:         parse(:longitude, :west),
        high:         parse(:altitude, :high),
        low:          parse(:altitude, :low),
        notes:        parse(:string, :notes)
      }
    end

    def update_params
      {
        display_name: parse(:string, :set_name, limit: 1024),
        north:        parse(:latitude, :set_north),
        south:        parse(:longitude, :set_south),
        east:         parse(:longitude, :set_east),
        west:         parse(:longitude, :set_west),
        high:         parse(:altitude, :set_high),
        low:          parse(:altitude, :set_low),
        notes:        parse(:string, :set_notes)
      }
    end

    def validate_create_params!(params)
      name = params[:display_name]
      raise MissingParameter.new(:name)  unless params[:display_name]
      raise MissingParameter.new(:north) unless params[:north]
      raise MissingParameter.new(:south) unless params[:south]
      raise MissingParameter.new(:east)  unless params[:east]
      raise MissingParameter.new(:west)  unless params[:west]
      make_sure_location_doesnt_exist!(name)
      make_sure_name_isnt_dubious!(name)
    end

    def validate_update_params!(params)
      name = params[:display_name]
      make_sure_location_doesnt_exist!(name)
      make_sure_name_isnt_dubious!(name)
      make_sure_not_setting_name_of_multiple_locations!
    end

    def delete
      raise NoMethodForAction.new("DELETE", action)
    end

    def must_have_edit_permission!(_obj); end

    ############################################################################

    private

    def make_sure_location_doesnt_exist!(name)
      return unless Location.find_by_name_or_reverse_name(name)
      raise LocationAlreadyExists.new(name)
    end

    def make_sure_name_isnt_dubious!(name)
      citations =
        Location.check_for_empty_name(name) +
        Location.check_for_dubious_commas(name) +
        Location.check_for_bad_country_or_state(name) +
        Location.check_for_bad_terms(name) +
        Location.check_for_bad_chars(name)
      return if citations.none?
      raise DubiousLocationName.new(citations)
    end

    def make_sure_not_setting_name_of_multiple_locations!
      raise TryingToSetMultipleLocationsToSameName.new \
        if query.num_results > 1
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def parse_bounding_box!
      n = parse(:latitude, :north)
      s = parse(:latitude, :south)
      e = parse(:longitude, :east)
      w = parse(:longitude, :west)
      return unless n || s || e || w
      return [n, s, e, w] if n && s && e && w
      raise NeedAllFourEdges.new
    end
  end
end
