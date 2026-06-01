# frozen_string_literal: true

module HerbariumRecordsHelper
  def herbarium_records_index_sorts
    [
      ["herbarium_name",   :sort_by_herbarium_name.t],
      ["herbarium_label",  :sort_by_herbarium_label.t],
      ["initial_det",      :sort_by_initial_det.t],
      ["accession_number", :sort_by_accession_number.t],
      ["created_at",       :sort_by_created_at.t],
      ["updated_at",       :sort_by_updated_at.t]
    ].freeze
  end

  # "Remove from observation" button on observations/show/_herbarium_records.
  # Detaches the herbarium_record from this observation without destroying
  # the record (since HRs can be associated with multiple observations).
  def remove_herbarium_record_button(h_r, obs)
    destroy_button(
      name: :REMOVE.l,
      target: herbarium_record_path(h_r.id, observation_id: obs.id),
      confirm: :show_observation_remove_herbarium_record.l,
      class: "remove_herbarium_record_link_#{h_r.id}",
      icon: :remove, btn: nil
    )
  end
end
