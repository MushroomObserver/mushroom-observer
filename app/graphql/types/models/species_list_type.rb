module Types::Models
  class SpeciesListType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true, resolver_method: :when_observed
    field :user_id, Integer, null: true
    field :where, String, null: true
    field :title, String, null: true
    field :notes, String, null: true
    field :rss_log_id, Integer, null: true
    field :location_id, Integer, null: true
    # belongs to
    field :location, Types::Models::LocationType, null: true
    field :rss_log, Types::Models::RssLogType, null: true
    field :user, Types::Models::UserType, null: true
    # has and belongs to many
    field :projects, [Types::Models::ProjectType], null: true
    field :observations, [Types::Models::ObservationType], null: true
    # has many
    field :comments, [Types::Models::CommentType], null: true
    field :interests, [Types::Models::InterestType], null: true
  end
end
