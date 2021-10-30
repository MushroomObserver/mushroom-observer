module Types::Models
  class License < Types::BaseObject
    field :id, Integer, null: false
    field :display_name, String, null: true
    field :url, String, null: true
    field :deprecated, Boolean, null: false
    field :form_name, String, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    # has many
    field :images, [Types::Models::Image], null: true
    field :location_descriptions, [Types::Models::LocationDescription], null: true
    field :name_descriptions, [Types::Models::NameDescription], null: true
    field :users, [Types::Models::User], null: true
  end
end
