module Types::Models
  class ArticleType < Types::BaseObject
    field :id, Integer, null: false
    field :title, String, null: true
    field :body, String, null: true
    field :user_id, Integer, null: true
    field :rss_log_id, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    # belongs to
    field :user, Types::Models::UserType, null: true
    field :rss_log, Types::Models::RssLogType, null: true
  end
end
