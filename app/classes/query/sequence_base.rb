module Query
  # Code common to all Sequence queries.
  class SequenceBase < Query::Base
    def model
      Sequence
    end

    def parameter_declarations
      super.merge(
        created_at?:        [:time],
        updated_at?:        [:time],
        observations?:      [Observation],
        users?:             [User],
        locus_has?:         :string,
        bases_has?:         :string,
        accession_has?:     :string
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_objects_by_id(:observations)
      initialize_model_do_objects_by_id(:users)
      initialize_model_do_search(:locus_has, :locus)
      initialize_model_do_search(:accession_has, :accession)
      super
    end

    def default_order
      "created_at"
    end
  end
end
