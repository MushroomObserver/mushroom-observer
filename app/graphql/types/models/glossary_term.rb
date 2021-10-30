module Types::Models
  class GlossaryTerm < Types::BaseObject
    field :id, Integer, null: false
    field :version, Integer, null: true
    field :user_id, Integer, null: true
    field :name, String, null: true
    field :thumb_image_id, Integer, null: true
    field :description, String, null: true
    field :rss_log_id, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    # belongs to
    field :thumb_image, Types::Models::Image, null: true
    field :rss_log, Types::Models::RssLog, null: true
    field :user, Types::Models::User, null: true
    # has and belongs to many
    field :images, [Types::Models::Image], null: true
  end
end
