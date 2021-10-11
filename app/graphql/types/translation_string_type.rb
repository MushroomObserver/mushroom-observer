module Types
  class TranslationStringType < Types::BaseObject
    field :id, ID, null: false
    field :version, Integer, null: true
    field :language_id, Integer, null: false
    field :tag, String, null: true
    field :text, String, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
  end
end
