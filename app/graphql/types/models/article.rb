module Types::Models
  class Article < Types::BaseObject
    # graphql-sugar style!
    # model_class Article

    # attribute :id, :title

    # long way:
    field :id, ID, null: false
    field :title, String, null: true
    field :body, String, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::Models::RssLog, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
