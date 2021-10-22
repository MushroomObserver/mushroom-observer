module Types::Models
  class ApiKey < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :last_used, GraphQL::Types::ISO8601DateTime, null: true
    field :num_uses, Integer, null: true
    field :user_id, Integer, null: false
    field :user, Types::Models::User, null: false
    field :key, String, null: false
    field :notes, String, null: true
    field :verified, GraphQL::Types::ISO8601DateTime, null: true
  end
end
