module Types
  class LicenseType < Types::BaseObject
    field :id, ID, null: false
    field :display_name, String, null: true
    field :url, String, null: true
    field :deprecated, Boolean, null: false
    field :form_name, String, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
