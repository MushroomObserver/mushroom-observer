module Query
  # All locations.
  class LocationAll < Query::LocationBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
