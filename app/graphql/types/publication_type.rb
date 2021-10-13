module Types
  class PublicationType < Types::BaseObject
    field :id, ID, null: false
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: true
    field :full, String, null: true
    field :link, String, null: true
    field :how_helped, String, null: true
    field :mo_mentioned, Boolean, null: true
    field :peer_reviewed, Boolean, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
