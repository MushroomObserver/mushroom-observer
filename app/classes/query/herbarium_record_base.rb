module Query
  # Code common to all herbarium_record searches.
  class HerbariumRecordBase < Query::Base
    def model
      HerbariumRecord
    end

    def parameter_declarations
      super.merge(
        created_at?:           [:time],
        updated_at?:           [:time],
        users?:                [User],
        herbaria?:             [:string],
        observations?:         [:string],
        has_notes?:            :boolean,
        initial_det?:          [:string],
        accession_number?:     [:string],
        notes_has?:            :string,
        initial_det_has?:      :string,
        accession_number_has?: :string
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_objects_by_id(:users)
      initialize_model_do_objects_by_name(
        Herbarium, :herbaria, "herbarium_records.herbarium_id"
      )
      if params[:observations]
        initialize_model_do_objects_by_id(
          :observations, "herbarium_records_observations.observation_id"
        )
        add_join(:herbarium_records_observations)
      end
      initialize_model_do_boolean(
        :has_notes,
        "COALESCE(herbarium_records.notes, '') != ''",
        "COALESCE(herbarium_records.notes, '') = ''"
      )
      initialize_model_do_exact_match(:initial_det)
      initialize_model_do_exact_match(:accession_number)
      initialize_model_do_search(:notes_has, :notes)
      initialize_model_do_search(:initial_det_has, :initial_det)
      initialize_model_do_search(:accession_number_has, :accession_number)
      super
    end

    def default_order
      "herbarium_label"
    end
  end
end
