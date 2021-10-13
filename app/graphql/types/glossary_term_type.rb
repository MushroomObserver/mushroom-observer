module Types
  class GlossaryTermType < Types::BaseObject
    field :id, ID, null: false
    field :version, Integer, null: true
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: false
    field :name, String, null: true
    field :thumb_image_id, Integer, null: true
    field :thumb_image, Types::ImageType, null: true
    field :description, String, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::RssLogType, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
