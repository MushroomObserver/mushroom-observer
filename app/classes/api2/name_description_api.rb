# frozen_string_literal: true

class API2
  # API for Name Description
  class NameDescriptionAPI < ModelAPI
    self.model = NameDescription

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
        names: parse_array(:name, :name),
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
