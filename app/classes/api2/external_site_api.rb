# frozen_string_literal: true

class API2
  # API for ExternalSite
  class ExternalSiteAPI < ModelAPI
    def model
      ExternalSite
    end

    def high_detail_page_length
      1000
    end

    def low_detail_page_length
      1000
    end

    def put_page_length
      1000
    end

    def delete_page_length
      1000
    end

    def high_detail_includes
      [:project]
    end

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
