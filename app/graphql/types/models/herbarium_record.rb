module Types::Models
  class HerbariumRecord < Types::BaseObject
    field :id, ID, null: false
    field :herbarium_id, Integer, null: false
    field :herbarium, Types::Models::Herbarium, null: false
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: false
    field :user, Types::Models::User, null: false
    field :initial_det, String, null: false
    field :accession_number, String, null: false
  end
end
