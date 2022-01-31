# frozen_string_literal: true

module Types::Models
  class GlossaryTermType < Types::BaseObject
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
    field :thumb_image, Types::Models::ImageType, null: true
    field :rss_log, Types::Models::RssLogType, null: true
    field :user, Types::Models::UserType, null: true
    
    # has and belongs to many
    field :images, [Types::Models::ImageType], null: true

    # custom fields
    field :img_src_thumb, String, null: true
    field :img_src_sm, String, null: true
    field :img_src_med, String, null: true
    field :img_src_lg, String, null: true
    field :img_src_huge, String, null: true
    field :img_src_full, String, null: true

    def img_src_thumb
      Image.url(:thumbnail, object.thumb_image_id)
    end

    def img_src_sm
      Image.url(:small, object.thumb_image_id)
    end

    def img_src_med
      Image.url(:medium, object.thumb_image_id)
    end

    def img_src_lg
      Image.url(:large, object.thumb_image_id)
    end

    def img_src_huge
      Image.url(:huge, object.thumb_image_id)
    end

    def img_src_full
      Image.url(:full_size, object.thumb_image_id)
    end
  end
end
