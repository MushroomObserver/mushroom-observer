# frozen_string_literal: true

class API2
  # API2 for ExternalSite
  class ExternalSiteAPI2 < ModelAPI2
    self.model = ExternalSite

    self.high_detail_page_length = 1000
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :project
    ]

    def query_params
      {
        where: sql_id_condition,
        name: parse(:string, :name)
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
