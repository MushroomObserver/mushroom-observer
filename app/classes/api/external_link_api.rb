# encoding: utf-8
class API
  # API queries on external_links table.
  class ExternalLinkAPI < ModelAPI
    self.model = ExternalLink

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :external_site,
      :object,
      :user
    ]

    def query_params
      {
        where:          sql_id_condition,
        created_at:     parse_time_range(:created_at),
        updated_at:     parse_time_range(:updated_at),
        users:          parse_users(:user),
        observations:   parse_observations(:observations),
        external_sites: parse_external_sites(:external_sites),
        url:            parse_string(:url)
      }
    end

    def build_object
      raise NoMethodForAction("POST", action)
    end

    def build_setter
      raise NoMethodForAction("PUT", action)
    end

    def delete
      raise NoMethodForAction("DELETE", action)
    end
  end
end
