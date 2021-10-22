module Types::Models
  class Comment < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :summary, String, null: true
    field :comment, String, null: true
    field :target_type, String, null: true
    field :target_id, Integer, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
