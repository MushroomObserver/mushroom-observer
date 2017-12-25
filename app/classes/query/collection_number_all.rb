module Query
  # All collection_numbers.
  class CollectionNumberAll < Query::CollectionNumberBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
