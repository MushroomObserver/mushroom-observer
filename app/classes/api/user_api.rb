# encoding: utf-8

class API
  class UserAPI < ModelAPI
    self.model = User

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
    ]

    def query_params
      {
        :where    => sql_id_condition,
        :created  => parse_time_ranges(:created),
        :modified => parse_time_ranges(:modified),
      }
    end

    def post
      raise NoMethodForAction(:post, action)
    end

    def put
      raise NoMethodForAction(:put, action)
    end

    def delete
      raise NoMethodForAction(:delete, action)
    end
  end
end
