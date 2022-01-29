# frozen_string_literal: true

module Types::Models
  class CollectionNumberType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :name, String, null: true
    field :number, String, null: true
    # belongs to
    field :user, Types::Models::UserType, null: true
    # has and belongs to many
    field :observations, [Types::Models::ObservationType], null: true
  end
end
