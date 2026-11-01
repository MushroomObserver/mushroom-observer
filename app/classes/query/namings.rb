# frozen_string_literal: true

class Query::Namings < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Naming])
  query_attr(:by_users, [User], param_alias: :by_user, always_index: false)
  query_attr(:observations, [Observation], param_alias: :observation)
  query_attr(:names, [Name], param_alias: :name)
  query_attr(:confidence, [:float])

  def alphabetical_by
    @alphabetical_by ||= Name[:sort_name]
  end

  def self.default_order
    :created_at
  end
end
