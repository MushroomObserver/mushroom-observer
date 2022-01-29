# frozen_string_literal: true

module Types::Models
  class TranslationStringType < Types::BaseObject
    field :id, Integer, null: false
    field :version, Integer, null: true
    field :language_id, Integer, null: false
    field :tag, String, null: true
    field :text, String, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    # belongs to
    field :language, Types::Models::LanguageType, null: false
    field :user, Types::Models::UserType, null: true
  end
end
