module Types::Models
  class Sequence < Types::BaseObject
    field :id, Integer, null: false
    field :observation_id, Integer, null: true
    field :observation, Types::Models::Observation, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :locus, String, null: true
    field :bases, String, null: true
    field :archive, String, null: true
    field :accession, String, null: true
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
