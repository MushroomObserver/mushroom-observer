module Types::Models
  class Donation < Types::BaseObject
    field :id, Integer, null: false
    field :amount, Float, null: true
    field :who, String, null: true
    field :email, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :anonymous, Boolean, null: false
    field :reviewed, Boolean, null: false
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :recurring, Boolean, null: true
  end
end
