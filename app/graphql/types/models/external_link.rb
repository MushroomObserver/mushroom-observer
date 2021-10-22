module Types::Models
  class ExternalLink < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :observation_id, Integer, null: true
    field :observation, Types::Models::Observation, null: true
    field :external_site_id, Integer, null: true
    field :external_site, Types::Models::ExternalSite, null: true
    field :url, String, null: true
  end
end
