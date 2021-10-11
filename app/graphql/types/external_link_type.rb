module Types
  class ExternalLinkType < Types::BaseObject
    field :id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: true
    field :observation_id, Integer, null: true
    field :observation, Types::ObservationType, null: true
    field :external_site_id, Integer, null: true
    field :external_site, Types::ExternalSiteType, null: true
    field :url, String, null: true
  end
end
