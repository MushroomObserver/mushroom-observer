module Query
  # Common code for all api_key queries.
  class ApiKeyBase < Query::Base
    def model
      ApiKey
    end

    def parameter_declarations
      super.merge(
        created_at?: [:time],
        updated_at?: [:time],
        notes_has?:  :string
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_search(:notes_has, :notes)
      super
    end

    def default_order
      "created_at"
    end
  end
end
