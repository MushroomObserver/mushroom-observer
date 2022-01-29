# frozen_string_literal: true

module Types::Models
  class ObservationViewType < Types::BaseObject
    field :id, Integer, null: false
    field :observation_id, Integer, null: true
    field :user_id, Integer, null: true
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    # belongs to
    field :observation, Types::Models::ObservationType, null: true
    field :user, Types::Models::UserType, null: true
  end
end
