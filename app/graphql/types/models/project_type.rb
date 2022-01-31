# frozen_string_literal: true

module Types::Models
  class ProjectType < Types::BaseObject
    field :id, Integer, null: false
    field :user_id, Integer, null: false
    field :admin_group_id, Integer, null: false
    field :user_group_id, Integer, null: false
    field :title, String, null: false
    field :summary, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :rss_log_id, Integer, null: true
    # belongs_to
    field :admin_group, Types::Models::UserGroupType, null: false
    field :user_group, Types::Models::UserGroupType, null: false
    field :user, Types::Models::UserType, null: false
    field :rss_log, Types::Models::RssLogType, null: true
    # has many
    field :comments, [Types::Models::CommentType], null: true
    field :interests, [Types::Models::InterestType], null: true
    # has and belongs to many
    field :images, [Types::Models::ImageType], null: true
    field :observations, [Types::Models::ObservationType], null: true
    field :species_lists, [Types::Models::SpeciesListType], null: true
  end
end
