# frozen_string_literal: true

module Types::Models
  class NamingType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :observation_id, Integer, null: true
    field :name_id, Integer, null: true
    field :user_id, Integer, null: true
    field :vote_cache, Float, null: true
    field :reasons, String, null: true

    # belongs to
    field :name, Types::Models::NameType, null: true
    field :observation, Types::Models::ObservationType, null: true
    field :user, Types::Models::UserType, null: true
    
    # has many
    field :votes, [Types::Models::VoteType], null: true
  end
end
