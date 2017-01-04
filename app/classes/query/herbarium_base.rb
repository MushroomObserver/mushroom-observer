module Query
  # Common code for all herbarium queries.
  class HerbariumBase < Query::Base
    def model
      Herbarium
    end

    # def parameter_declarations
    #   super.merge(
    #   )
    # end

    # def initialize_flavor
    #   super
    # end

    def default_order
      "name"
    end
  end
end
