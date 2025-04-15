# frozen_string_literal: true

class Query::Comments < Query::Base
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Comment])
  query_attr(:by_users, [User])
  query_attr(:for_user, User)
  query_attr(:target, { type: :string, id: AbstractModel })
  query_attr(:types, [{ string: Comment::ALL_TYPE_TAGS }])
  query_attr(:summary_has, :string)
  query_attr(:content_has, :string)
  query_attr(:pattern, :string)

  def alphabetical_by
    @alphabetical_by ||= User[:login]
  end

  def self.default_order
    :created_at
  end
end
