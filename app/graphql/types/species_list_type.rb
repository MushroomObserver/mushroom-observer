module Types
  class SpeciesListType < Types::BaseObject
    field :id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true
    field :user_id, Integer, null: true
    field :where, String, null: true
    field :title, String, null: true
    field :notes, String, null: true
    field :rss_log_id, Integer, null: true
    field :location_id, Integer, null: true
  end
end
