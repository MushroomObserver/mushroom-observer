module Types::Models
  class CopyrightChange < Types::BaseObject
    field :id, Integer, null: false
    field :user_id, Integer, null: false
    field :user, Types::Models::User, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :target_type, String, null: false
    field :target_id, Integer, null: false
    field :year, Integer, null: true
    field :name, String, null: true
    field :license_id, Integer, null: true
    field :license, Types::Models::License, null: true
  end
end
