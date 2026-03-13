# frozen_string_literal: true

class API2
  # API for ExternalSite
  class ExternalSiteAPI < ModelAPI
    def model
      ExternalSite
    end

    def page_length_level
      :lightweight
    end

    def high_detail_includes
      [:project]
    end

    def query_params
      {
        id_in_set: parse_array(:external_site, :id, as: :id),
        name_has: parse(:string, :name)
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
