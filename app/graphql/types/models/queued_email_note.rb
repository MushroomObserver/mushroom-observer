module Types::Models
  class QueuedEmailNote < Types::BaseObject
    field :id, ID, null: false
    field :queued_email_id, Integer, null: false
    field :value, String, null: true
    # belongs to
    field :queued_email, Types::Models::QueuedEmail, null: true
  end
end
