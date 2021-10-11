module Types
  class NotificationType < Types::BaseObject
    field :id, ID, null: false
    field :user_id, Integer, null: false
    field :flavor, Integer, null: true
    field :obj_id, Integer, null: true
    field :note_template, String, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :require_specimen, Boolean, null: false
  end
end
