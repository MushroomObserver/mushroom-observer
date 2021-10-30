module Types::Models
  class UserGroup < Types::BaseObject
    field :id, Integer, null: false
    field :name, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :meta, Boolean, null: true
    # has one
    field :project, Types::Models::Project, null: true
    field :admin_project, Types::Models::Project, null: true
    # has and belongs to many
    field :users, [Types::Models::User], null: true
  end
end
