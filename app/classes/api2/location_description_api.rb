# frozen_string_literal: true

class API2
  # API for Location Description
  class LocationDescriptionAPI < ModelAPI
    def model
      LocationDescription
    end

    def high_detail_page_length
      100
    end

    def low_detail_page_length
      100
    end

    def put_page_length
      100
    end

    def delete_page_length
      100
    end

    def low_detail_includes
      [:license]
    end

    def high_detail_includes
      []
    end

    def query_params
      {
        ids: parse_array(:integer, :id),
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
