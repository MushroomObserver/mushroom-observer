module Types::Models
  class QueuedEmail < Types::BaseObject
    field :id, ID, null: false
    field :user_id, Integer, null: true
    field :queued, GraphQL::Types::ISO8601DateTime, null: true
    field :num_attempts, Integer, null: true
    field :flavor, String, null: true
    field :to_user_id, Integer, null: true
    # belongs to
    field :user, Types::Models::User, null: true
    field :to_user, Types::Models::User, null: true
    # has one
    field :queued_email_note, Types::Models::QueuedEmailNote, null: true
    # has_many
    field :queued_email_integers, [Types::Models::QueuedEmailInteger], null: true
    field :queued_email_strings, [Types::Models::QueuedEmailString], null: true
  end
end
