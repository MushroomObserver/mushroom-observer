module Types::Models
  class Location < Types::BaseObject
    field :id, ID, null: false
    field :version, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :description_id, Integer, null: true
    # field :description, Types::Models::LocationDescription, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::Models::RssLog, null: true
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

    # field :descriptions, [Types::Models::LocationDescription], null: true
    field :comments, [Types::Models::Comment], null: true
    field :interests, [Types::Models::Interest], null: true
    field :observations, [Types::Models::Observation], null: true
    field :species_lists, [Types::Models::SpeciesList], null: true
    field :herbaria, [Types::Models::Herbarium], null: true
    field :users, [Types::Models::User], null: true
  end
end
