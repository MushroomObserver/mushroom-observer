# frozen_string_literal: true

class API2
  # API for Name Description
  class NameDescriptionAPI < ModelAPI
    def model
      NameDescription
    end

    def page_length_level
      :heavyweight
    end

    def low_detail_includes
      [:license]
    end

    def high_detail_includes
      []
    end

    def query_params
      {
        id_in_set: parse_array(:name_description, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        by_users: parse_array(:user, :user, help: :first_user),
        is_public: true
      }.merge(parse_names_parameters)
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
