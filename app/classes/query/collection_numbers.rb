# frozen_string_literal: true

class Query::CollectionNumbers < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [CollectionNumber])
  query_attr(:by_users, [User], param_alias: :by_user, always_index: false)
  query_attr(:collectors, [:string])
  query_attr(:numbers, [:string])
  query_attr(:collector_has, :string)
  query_attr(:number_has, :string)
  query_attr(:observations, [Observation], param_alias: :observation,
                                           redirect_to: :model_index)
  query_attr(:pattern, :string)

  def alphabetical_by
    @alphabetical_by ||= CollectionNumber[:name]
  end

  def self.default_order
    :name_and_number
  end
end
