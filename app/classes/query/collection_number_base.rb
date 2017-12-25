module Query
  # Code common to all collection_number searches.
  class CollectionNumberBase < Query::Base
    def model
      CollectionNumber
    end

    def parameter_declarations
      super.merge(
        created_at?:   [:time],
        updated_at?:   [:time],
        users?:        [User],
        observations?: [:string],
        name?:         [:string],
        number?:       [:string],
        name_has?:     :string,
        number_has?:   :string
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_objects_by_id(:users)
      if params[:observations]
        initialize_model_do_objects_by_id(
          :observations, "collection_numbers_observations.observation_id"
        )
        add_join(:collection_numbers_observations)
      end
      initialize_model_do_exact_match(:name)
      initialize_model_do_exact_match(:number)
      initialize_model_do_search(:name_has, :name)
      initialize_model_do_search(:number_has, :number)
      super
    end

    def default_order
      "name_and_number"
    end
  end
end
