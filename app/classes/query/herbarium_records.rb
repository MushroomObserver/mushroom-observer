# frozen_string_literal: true

class Query::HerbariumRecords < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [HerbariumRecord])
  query_attr(:by_users, [User])
  query_attr(:has_notes, :boolean)
  query_attr(:notes_has, :string)
  query_attr(:initial_det, [:string])
  query_attr(:initial_det_has, :string)
  query_attr(:accession, [:string])
  query_attr(:accession_has, :string)
  query_attr(:herbaria, [Herbarium], param_alias: :herbarium)
  query_attr(:observations, [Observation], param_alias: :observation,
                                           redirect_to: :model_index)
  query_attr(:pattern, :string)

  def alphabetical_by
    @alphabetical_by ||= HerbariumRecord[:initial_det]
  end

  def self.default_order
    :herbarium_label
  end
end
