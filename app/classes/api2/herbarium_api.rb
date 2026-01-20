# frozen_string_literal: true

class API2
  # API for Herbarium
  class HerbariumAPI < ModelAPI
    def model
      Herbarium
    end

    def high_detail_includes
      [
        :location,
        :personal_user
      ]
    end

    def query_params
      {
        id_in_set: parse_array(:herbarium, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        code_has: parse(:string, :code),
        name_has: parse(:string, :name),
        description_has: parse(:string, :description),
        mailing_address_has: parse(:string, :address, help: :mailing_address)
      }
    end

    def post
      raise(NoMethodForAction.new("POST", :external_sites))
    end

    def patch
      raise(NoMethodForAction.new("PATCH", :external_sites))
    end

    def delete
      raise(NoMethodForAction.new("DELETE", :external_sites))
    end
  end
end
