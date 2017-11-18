module Query
  # Common code for all herbarium queries.
  class HerbariumBase < Query::Base
    def model
      Herbarium
    end

    def parameter_declarations
      super.merge(
        created_at?:     [:time],
        updated_at?:     [:time],
        code?:           :string,
        name?:           :string,
        description?:    :string,
        address?:        :string
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_search(:code, :code)
      initialize_model_do_search(:name, :name)
      initialize_model_do_search(:description, :description)
      initialize_model_do_search(:address, :mailing_address)
      super
    end

    def default_order
      "name"
    end
  end
end
