# frozen_string_literal: true

module Types::Models
  class ExternalLinkType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :observation_id, Integer, null: true
    field :external_site_id, Integer, null: true
    field :url, String, null: true
    # belongs to
    field :external_site, Types::Models::ExternalSiteType, null: true
    field :observation, Types::Models::ObservationType, null: true
    field :user, Types::Models::UserType, null: true
  end
end
