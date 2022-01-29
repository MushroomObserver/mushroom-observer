# frozen_string_literal: true

module Types::Models
  class LicenseType < Types::BaseObject
    field :id, Integer, null: false
    field :display_name, String, null: true
    field :url, String, null: true
    field :deprecated, Boolean, null: false
    field :form_name, String, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    # has many
    field :images, [Types::Models::ImageType], null: true
    field :location_descriptions, [Types::Models::LocationDescriptionType], null: true
    field :name_descriptions, [Types::Models::NameDescriptionType], null: true
    field :users, [Types::Models::UserType], null: true
  end
end
