# frozen_string_literal: true

module Types::Models
  class NotificationType < Types::BaseObject
    field :id, Integer, null: false
    field :user_id, Integer, null: false
    field :flavor, Integer, null: true
    field :obj_id, Integer, null: true
    field :note_template, String, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :require_specimen, Boolean, null: false
    
    # belongs to
    field :user, Types::Models::UserType, null: false
  end
end
