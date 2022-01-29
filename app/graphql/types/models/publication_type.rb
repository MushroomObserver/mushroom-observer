module Types::Models
  class PublicationType < Types::BaseObject
    field :id, Integer, null: false
    field :user_id, Integer, null: true
    field :full, String, null: true
    field :link, String, null: true
    field :how_helped, String, null: true
    field :mo_mentioned, Boolean, null: true
    field :peer_reviewed, Boolean, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    # belongs to
    field :user, Types::Models::UserType, null: true
  end
end
