# frozen_string_literal: true

module Types::Models
  class VoteType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :naming_id, Integer, null: true
    field :user_id, Integer, null: true
    field :observation_id, Integer, null: true
    field :favorite, Boolean, null: true
    field :value, Float, null: true
    
    # belongs to
    field :user, Types::Models::UserType, null: true
    field :naming, Types::Models::NamingType, null: true
    field :observation, Types::Models::ObservationType, null: true
  end
end
