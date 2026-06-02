# frozen_string_literal: true

module CollectionNumbersHelper
  def collection_numbers_index_sorts
    [
      ["name",       :sort_by_name.l],
      ["number",     :sort_by_number.l],
      ["created_at", :sort_by_created_at.l],
      ["updated_at", :sort_by_updated_at.l]
    ].freeze
  end

  # "Remove from observation" button on observations/show/_collection_numbers.
  # Detaches the collection_number from this observation without destroying
  # the record (since CNs can be associated with multiple observations).
  def remove_collection_number_button(c_n, obs)
    destroy_button(
      name: :REMOVE.l,
      target: collection_number_path(c_n.id, observation_id: obs.id),
      confirm: :show_observation_remove_collection_number.l,
      class: "remove_collection_number_link_#{c_n.id}",
      icon: :remove, btn: nil
    )
  end
end
