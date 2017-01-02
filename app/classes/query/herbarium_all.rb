module Query
  # All herbaria.
  class HerbariumAll < Query::HerbariumBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
