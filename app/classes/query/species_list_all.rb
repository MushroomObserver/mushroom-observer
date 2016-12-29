module Query
  # All species lists.
  class SpeciesListAll < Query::SpeciesListBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
