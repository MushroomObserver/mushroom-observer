# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :user_delete, mutation: Mutations::User::Delete
    field :user_update, mutation: Mutations::User::Update
    field :user_create, mutation: Mutations::User::Create
    field :user_login, mutation: Mutations::User::Login

    # TODO: remove me
    # field :test_field, String, null: false,
    #                            description: "An example field added by the generator"
    # def test_field
    #   "Hello World"
    # end
  end
end
