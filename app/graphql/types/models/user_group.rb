module Types::Models
  class UserGroup < Types::BaseObject
    field :id, Integer, null: false
    field :name, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :meta, Boolean, null: true
  end
end
