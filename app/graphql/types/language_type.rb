module Types
  class LanguageType < Types::BaseObject
    field :id, ID, null: false
    field :locale, String, null: true
    field :name, String, null: true
    field :order, String, null: true
    field :official, Boolean, null: false
    field :beta, Boolean, null: false
  end
end
