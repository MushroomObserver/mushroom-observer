# frozen_string_literal: true

# app/graphql/mutations/login_user.rb

module Mutations
  class LoginUser < Mutations::BaseMutation
    description "Login a user"

    input_object_class Types::LoginInput

    type Types::UserType

    def resolve(login: String,
                password: String)
      user = User.authenticate(login, password)
      return {} unless user

      token = Base64.encode64(user.login)
      {
        token: token,
        user: user
      }
    rescue ActiveRecord::RecordNotFound
      raise(GraphQL::ExecutionError.new("user not found"))
    end
  end
end
