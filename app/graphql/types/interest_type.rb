module Types
  class InterestType < Types::BaseObject
    field :id, ID, null: false
    field :target_type, String, null: true
    field :target_id, Integer, null: true
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: true
    field :state, Boolean, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
