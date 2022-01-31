# frozen_string_literal: true

module Types::Models
  class DonationType < Types::BaseObject
    field :id, Integer, null: false
    field :amount, Float, null: true
    field :who, String, null: true
    field :email, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :anonymous, Boolean, null: false
    field :reviewed, Boolean, null: false
    field :user_id, Integer, null: true
    field :recurring, Boolean, null: true
    
    # belongs to
    field :user, Types::Models::UserType, null: true
  end
end
