module Types::Models
  class HerbariumType < Types::BaseObject
    field :id, Integer, null: false
    field :mailing_address, String, null: true
    field :location_id, Integer, null: true
    field :email, String, null: false
    field :name, String, null: true
    field :description, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :code, String, null: false
    field :personal_user_id, Integer, null: true
    # belongs to
    field :location, Types::Models::LocationType, null: true
    field :personal_user, Types::Models::UserType, null: true
    # has many
    field :herbarium_records, [Types::Models::HerbariumRecordType], null: true
    # has and belongs to many
    field :curators, [Types::Models::UserType], null: true
  end
end
