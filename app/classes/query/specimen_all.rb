module Query
  # All specimens.
  class SpecimenAll < Query::SpecimenBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
