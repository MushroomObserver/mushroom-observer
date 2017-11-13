module Query
  # All api_keys.
  class ApiKeyAll < Query::ApiKeyBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
