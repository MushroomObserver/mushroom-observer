module Types::Models
  class ApiKeyType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :last_used, GraphQL::Types::ISO8601DateTime, null: true
    field :num_uses, Integer, null: true
    field :user_id, Integer, null: false
    field :key, String, null: false
    field :notes, String, null: true
    field :verified, GraphQL::Types::ISO8601DateTime, null: true
    # belongs to
    field :user, Types::Models::UserType, null: false
  end
end
