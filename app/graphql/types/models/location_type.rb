# frozen_string_literal: true

module Types::Models
  class LocationType < Types::BaseObject
    field :id, Integer, null: false
    field :version, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :description_id, Integer, null: true
    field :rss_log_id, Integer, null: true
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
    # belongs to
    field :description, Types::Models::LocationDescriptionType, null: true
    field :rss_log, Types::Models::RssLogType, null: true
    field :user, Types::Models::UserType, null: true
    # has many
    field :descriptions, [Types::Models::LocationDescriptionType], null: true
    field :comments, [Types::Models::CommentType], null: true
    field :interests, [Types::Models::InterestType], null: true
    field :observations, [Types::Models::ObservationType], null: true
    field :species_lists, [Types::Models::SpeciesListType], null: true
    field :herbaria, [Types::Models::HerbariumType], null: true
    field :users, [Types::Models::UserType], null: true
  end
end
