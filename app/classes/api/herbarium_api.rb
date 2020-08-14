# frozen_string_literal: true

class API
  # API for Herbarium
  class HerbariumAPI < ModelAPI
    self.model = Herbarium

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :location,
      :personal_user
    ]

    def query_params
      {
        where: sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        code: parse(:string, :code),
        name: parse(:string, :name),
        description: parse(:string, :description),
        address: parse(:string, :address, help: :mailing_address)
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
