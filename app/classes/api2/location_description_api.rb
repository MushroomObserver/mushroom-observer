# frozen_string_literal: true

class API2
  # API for Location Description
  class LocationDescriptionAPI < ModelAPI
    self.model = LocationDescription

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 100
    self.put_page_length         = 100
    self.delete_page_length      = 100

    self.low_detail_includes = [
      :license
    ]

    self.high_detail_includes = []

    def query_params
      {
        where: sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        users: parse_array(:user, :user, help: :first_user),
        locations: parse_array(:location, :location),
        public: true
      }
    end

    def post
      raise(NoMethodForAction.new("POST", action))
    end

    def patch
      raise(NoMethodForAction.new("PATCH", action))
    end

    def delete
      raise(NoMethodForAction.new("DELETE", action))
    end
  end
end
