# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :delete_user, mutation: Mutations::User::Delete
    field :update_user, mutation: Mutations::User::Update
    field :create_user, mutation: Mutations::User::Create
    field :login_user, mutation: Mutations::User::Login

    # TODO: remove me
    field :test_field, String, null: false,
                               description: "An example field added by the generator"
    def test_field
      "Hello World"
    end
  end
end
