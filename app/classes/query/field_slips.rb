# frozen_string_literal: true

class Query::FieldSlips < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [FieldSlip])
  query_attr(:by_users, [User], param_alias: :by_user,
                                redirect_to: :model_index,
                                always_index: false)
  query_attr(:code, [:string])
  query_attr(:code_has, [:string])
  query_attr(:observation, [Observation])
  query_attr(:projects, [Project], param_alias: :project,
                                   redirect_to: :model_index)

  def self.default_order
    :code_then_date
  end
end
