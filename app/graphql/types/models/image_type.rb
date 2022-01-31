# frozen_string_literal: true

module Types::Models
  class ImageType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :content_type, String, null: true
    field :user_id, Integer, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true,
                                              resolver_method: :when_observed
    field :notes, String, null: true
    field :copyright_holder, String, null: true
    field :license_id, Integer, null: false
    field :num_views, Integer, null: false
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :width, Integer, null: true
    field :height, Integer, null: true
    field :vote_cache, Float, null: true
    field :ok_for_export, Boolean, null: false
    field :original_name, String, null: true
    field :transferred, Boolean, null: false
    field :gps_stripped, Boolean, null: false

    # belongs to
    field :license, Types::Models::LicenseType, null: false
    field :user, Types::Models::UserType, null: true
    field :reviewer, Types::Models::UserType, null: true

    # has many
    field :thumb_clients, [Types::Models::ObservationType], null: true
    field :image_votes, [Types::Models::VoteType], null: true
    field :subjects, [Types::Models::UserType], null: true
    field :best_glossary_terms, [Types::Models::GlossaryTermType], null: true
    field :copyright_changes, [Types::Models::CopyrightChangeType], null: true

    # has and belongs to many
    field :observations, [Types::Models::ObservationType], null: true
    field :projects, [Types::Models::ProjectType], null: true
    field :glossary_terms, [Types::Models::GlossaryTermType], null: true

    # custom fields
    field :img_src_thumb, String, null: true
    field :img_src_sm, String, null: true
    field :img_src_med, String, null: true
    field :img_src_lg, String, null: true
    field :img_src_huge, String, null: true
    field :img_src_full, String, null: true

    def img_src_thumb
      Image.url(:thumbnail, object.image_id)
    end

    def img_src_sm
      Image.url(:small, object.image_id)
    end

    def img_src_med
      Image.url(:medium, object.image_id)
    end

    def img_src_lg
      Image.url(:large, object.image_id)
    end

    def img_src_huge
      Image.url(:huge, object.image_id)
    end

    def img_src_full
      Image.url(:full, object.image_id)
    end
  end
end
