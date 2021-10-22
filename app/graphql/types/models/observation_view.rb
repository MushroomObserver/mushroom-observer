module Types::Models
  class ObservationView < Types::BaseObject
    field :id, Integer, null: false
    field :observation_id, Integer, null: true
    field :observation, Types::Models::Observation, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
  end
end
