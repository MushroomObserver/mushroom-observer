class Query::HerbariumRecordBase < Query::Base
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
    add_owner_and_time_stamp_conditions("herbarium_records")
    add_id_condition("herbarium_records.herbarium_id",
                     lookup_herbaria_by_name(params[:herbaria]))
    add_id_condition("herbarium_records_observations.observation_id",
                     params[:observations], :herbarium_records_observations)
    add_boolean_condition("COALESCE(herbarium_records.notes,'') != ''",
                          "COALESCE(herbarium_records.notes,'') = ''",
                          params[:has_notes])
    add_exact_match_condition("herbarium_records.initial_det",
                              params[:initial_det])
    add_exact_match_condition("herbarium_records.accession_number",
                              params[:accession_number])
    add_search_condition("herbarium_records.notes",
                         params[:notes_has])
    add_search_condition("herbarium_records.initial_det",
                         params[:initial_det_has])
    add_search_condition("herbarium_records.accession_number",
                         params[:accession_number_has])
    super
  end

  def default_order
    "herbarium_label"
  end
end
