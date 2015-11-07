# encoding: utf-8

class API
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
        where: sql_id_condition,
        created_at: parse_time_range(:created_at),
        updated_at: parse_time_range(:updated_at),
        users: parse_users(:user),
        north: parse_latitude(:north),
        south: parse_latitude(:south),
        east: parse_longitude(:east),
        west: parse_longitude(:west)
      }
    end

    def create_params
      {
        display_name: parse_string(:name, limit: 1024),
        north: parse_latitude(:north),
        south: parse_longitude(:south),
        east: parse_longitude(:east),
        west: parse_longitude(:west),
        high: parse_altitude(:high, default: nil),
        low: parse_altitude(:low, default: nil),
        notes: parse_string(:notes, default: "")
      }
    end

    def validate_create_params!(params)
      fail MissingParameter.new(:name)  if params[:name].blank?
      fail MissingParameter.new(:north) if params[:north].blank?
      fail MissingParameter.new(:south) if params[:south].blank?
      fail MissingParameter.new(:east)  if params[:east].blank?
      fail MissingParameter.new(:west)  if params[:west].blank?
      name = params[:display_name].to_s
      if Location.find_by_name_or_reverse_name(name)
        fail LocationAlreadyExists.new(name)
      end
    end

    def update_params
      if name = parse_string(:set_name, limit: 1024)
        if Location.find_by_name_or_reverse_name(name)
          fail LocationAlreadyExists.new(name)
        end
        fail TryingToSetMultipleLocationsToSameName.new if query.num_results > 1
      end

      {
        display_name: name,
        north: parse_latitude(:set_north),
        south: parse_longitude(:set_south),
        east: parse_longitude(:set_east),
        west: parse_longitude(:set_west),
        high: parse_altitude(:set_high),
        low: parse_altitude(:set_low),
        notes: parse_string(:set_notes)
      }
    end

    def must_have_edit_permission!(_obj)
    end

    def delete
      fail NoMethodForAction.new("DELETE", action)
    end
  end
end
