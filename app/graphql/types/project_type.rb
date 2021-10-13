module Types
  class ProjectType < Types::BaseObject
    field :id, ID, null: false
    field :user_id, Integer, null: false
    field :user, Types::UserType, null: false
    field :admin_group_id, Integer, null: false
    field :admin_group, Types::UserGroupType, null: false
    field :user_group_id, Integer, null: false
    field :user_group, Types::UserGroupType, null: false
    field :title, String, null: false
    field :summary, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::RssLogType, null: true
  end
end
