module Types
  class HerbariumRecordType < Types::BaseObject
    field :id, ID, null: false
    field :herbarium_id, Integer, null: false
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: false
    field :initial_det, String, null: false
    field :accession_number, String, null: false
  end
end
