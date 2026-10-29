# frozen_string_literal: true

class Query::Interests < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Interest])
  # Forced to the current user by InterestsController, not read from
  # request params -- Interests are private.
  query_attr(:by_users, [User], param_alias: :by_user, always_index: false)
  query_attr(:types, [{ string: Interest::ALL_TYPE_TAGS }])
  query_attr(:state, :boolean)

  def self.default_order
    :target_type
  end
end
