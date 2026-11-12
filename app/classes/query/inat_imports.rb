# frozen_string_literal: true

class Query::InatImports < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:by_users, [User], param_alias: :by_user, always_index: false)

  def self.default_order
    :updated_at
  end
end
