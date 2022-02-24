# frozen_string_literal: true

# This file defines all possible graphql mutations
module Types
  class MutationType < Types::BaseObject
    field :user_login, mutation: Mutations::User::Login
    field :user_admin_mode, mutation: Mutations::User::AdminMode
    field :user_change_password, mutation: Mutations::User::ChangePassword
    field :user_create, mutation: Mutations::User::Create
    field :user_update, mutation: Mutations::User::Update
    field :user_delete, mutation: Mutations::User::Delete
  end
end
