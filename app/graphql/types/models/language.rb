module Types::Models
  class Language < Types::BaseObject
    field :id, Integer, null: false
    field :locale, String, null: true
    field :name, String, null: true
    field :order, String, null: true
    field :official, Boolean, null: false
    field :beta, Boolean, null: false
    # has many
    field :translation_strings, [Types::Models::TranslationString], null: true
  end
end
