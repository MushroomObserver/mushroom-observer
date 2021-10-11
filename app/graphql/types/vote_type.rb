module Types
  class VoteType < Types::BaseObject
    field :id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :naming_id, Integer, null: true
    field :naming, Types::NamingType, null: true
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: true
    field :observation_id, Integer, null: true
    field :observation, Types::ObservationType, null: true
    field :favorite, Boolean, null: true
    field :value, Float, null: true
  end
end
