module Types::Models
  class HerbariumRecord < Types::BaseObject
    field :id, Integer, null: false
    field :herbarium_id, Integer, null: false
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: false
    field :initial_det, String, null: false
    field :accession_number, String, null: false
    # belongs to
    field :herbarium, Types::Models::Herbarium, null: false
    field :user, Types::Models::User, null: false
    # has and belongs to many
    field :observations, [Types::Models::Observation], null: true
  end
end
