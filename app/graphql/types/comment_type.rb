module Types
  class CommentType < Types::BaseObject
    field :id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: true
    field :summary, String, null: true
    field :comment, String, null: true
    field :target_type, String, null: true
    field :target_id, Integer, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
