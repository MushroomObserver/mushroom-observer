module Types
  class HerbariumType < Types::BaseObject
    field :id, ID, null: false
    field :mailing_address, String, null: true
    field :location_id, Integer, null: true
    field :location, Types::LocationType, null: true
    field :email, String, null: false
    field :name, String, null: true
    field :description, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :code, String, null: false
    field :personal_user_id, Integer, null: true
    field :personal_user, Types::UserType, null: true

    field :herbarium_records, [Types::HerbariumRecordType], null: true
    field :curators, [Types::UserType], null: true
  end
end
