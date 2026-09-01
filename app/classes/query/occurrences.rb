# frozen_string_literal: true

class Query::Occurrences < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Occurrence])
  query_attr(:by_users, [User], param_alias: :by_user, always_index: false)
  query_attr(:observations, [Observation], param_alias: :observation)
  query_attr(:field_slips, [FieldSlip], param_alias: :field_slip)

  def self.default_order
    :created_at
  end
end
