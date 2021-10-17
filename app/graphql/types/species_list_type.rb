module Types
  class SpeciesListType < Types::BaseObject
    field :id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: true
    field :where, String, null: true
    field :title, String, null: true
    field :notes, String, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::RssLogType, null: true
    field :location_id, Integer, null: true
    field :location, Types::LocationType, null: true

    field :projects, [Types::ProjectType], null: true
    field :observations, [Types::ObservationType], null: true
    field :comments, [Types::CommentType], null: true
    field :interests, [Types::InterestType], null: true
  end
end
