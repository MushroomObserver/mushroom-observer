# frozen_string_literal: true

# This file defines all possible graphql mutations
module Types
  class MutationType < Types::BaseObject
    # field :user_delete, mutation: Mutations::User::Delete
    # field :user_update, mutation: Mutations::User::Update
    # field :user_create, mutation: Mutations::User::Create
    field :user_login, mutation: Mutations::User::Login
  end
end
