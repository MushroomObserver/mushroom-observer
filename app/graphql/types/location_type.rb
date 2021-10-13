module Types
  class LocationType < Types::BaseObject
    field :id, ID, null: false
    field :version, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: false
    field :description_id, Integer, null: true
    # field :description, Types::LocationDescription, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::RssLogType, null: true
    field :num_views, Integer, null: true
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :north, Float, null: true
    field :south, Float, null: true
    field :west, Float, null: true
    field :east, Float, null: true
    field :high, Float, null: true
    field :low, Float, null: true
    field :ok_for_export, Boolean, null: false
    field :notes, String, null: true
    field :name, String, null: true
    field :scientific_name, String, null: true
    field :locked, Boolean, null: false
  end
end
