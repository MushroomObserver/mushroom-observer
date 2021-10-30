module Types::Models
  class Vote < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :naming_id, Integer, null: true
    field :user_id, Integer, null: true
    field :observation_id, Integer, null: true
    field :favorite, Boolean, null: true
    field :value, Float, null: true
    # belongs to
    field :user, Types::Models::User, null: true
    field :naming, Types::Models::Naming, null: true
    field :observation, Types::Models::Observation, null: true
  end
end
