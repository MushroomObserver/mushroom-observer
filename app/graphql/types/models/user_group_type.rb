module Types::Models
  class UserGroupType < Types::BaseObject
    field :id, Integer, null: false
    field :name, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :meta, Boolean, null: true
    # has one
    field :project, Types::Models::ProjectType, null: true
    field :admin_project, Types::Models::ProjectType, null: true
    # has and belongs to many
    field :users, [Types::Models::UserType], null: true
  end
end
