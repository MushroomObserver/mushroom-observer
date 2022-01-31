# frozen_string_literal: true

module Types::Models
  class CommentType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :summary, String, null: true
    field :comment, String, null: true
    field :target_type, String, null: true
    field :target_id, Integer, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    # belongs to
    field :user, Types::Models::UserType, null: true
    field :target, Types::Unions::InterestTarget, null: false
  end
end
