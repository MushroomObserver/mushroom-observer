module Types::Models
  class QueuedEmailInteger < Types::BaseObject
    field :id, ID, null: false
    field :queued_email_id, Integer, null: false
    field :key, String, null: true
    field :value, Integer, null: false
    # belongs to
    field :queued_email, Types::Models::QueuedEmail, null: true
  end
end
