module Types::Models
  class Image < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :content_type, String, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true
    field :notes, String, null: true
    field :copyright_holder, String, null: true
    field :license_id, Integer, null: false
    field :license, Types::Models::License, null: false
    field :num_views, Integer, null: false
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :width, Integer, null: true
    field :height, Integer, null: true
    field :vote_cache, Float, null: true
    field :ok_for_export, Boolean, null: false
    field :original_name, String, null: true
    field :transferred, Boolean, null: false
    field :gps_stripped, Boolean, null: false

    field :observations, [Types::Models::Observation], null: true
    field :projects, [Types::Models::Project], null: true
    field :glossary_terms, [Types::Models::GlossaryTerm], null: true
    field :best_glossary_terms, [Types::Models::GlossaryTerm], null: true
    field :thumb_clients, [Types::Models::Observation], null: true
    field :image_votes, [Types::Models::Vote], null: true
    field :subjects, [Types::Models::User], null: true
    field :copyright_changes, [Types::Models::CopyrightChange], null: true
  end
end
