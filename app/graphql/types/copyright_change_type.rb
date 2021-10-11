module Types
  class CopyrightChangeType < Types::BaseObject
    field :id, ID, null: false
    field :user_id, Integer, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :target_type, String, null: false
    field :target_id, Integer, null: false
    field :year, Integer, null: true
    field :name, String, null: true
    field :license_id, Integer, null: true
  end
end
