module Types::Models
  class SpeciesList < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true, resolver_method: :when_observed
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :where, String, null: true
    field :title, String, null: true
    field :notes, String, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::Models::RssLog, null: true
    field :location_id, Integer, null: true
    field :location, Types::Models::Location, null: true

    field :projects, [Types::Models::Project], null: true
    field :observations, [Types::Models::Observation], null: true
    field :comments, [Types::Models::Comment], null: true
    field :interests, [Types::Models::Interest], null: true
  end
end
