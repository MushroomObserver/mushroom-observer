module Query
  # Herbaria in a given set.
  class HerbariumInSet < Query::HerbariumBase
    def parameter_declarations
      super.merge(
        ids: [Herbarium]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("herbaria")
      super
    end
  end
end
