# frozen_string_literal: true

class Query::Comments < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Comment])
  # always_index: false on both -- a single matching comment
  # auto-redirects straight to it rather than showing a one-row index
  # (tested, deliberate: see test_index_by_user_who_created_one_comment/
  # test_index_for_user_who_received_one_comment).
  query_attr(:by_users, [User], param_alias: :by_user, always_index: false)
  # param_alias: matches its own attr name here -- not a rename, just
  # opts this into create_query_from_url_params's record-lookup path.
  query_attr(:for_user, User, param_alias: :for_user, always_index: false)
  query_attr(:target, { polymorphic: Comment::ALL_TYPES })
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
