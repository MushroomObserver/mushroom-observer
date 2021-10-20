# frozen_string_literal: true

# app/graphql/mutations/login_user.rb
# For some reason this doesn't work with resolve(**arguments)

module Mutations
  class LoginUser < Mutations::BaseMutation
    description "Login a user"

    input_object_class Inputs::LoginUserInput

    field :token, String, null: true
    field :user, Types::Models::User, null: true

    def resolve(**arguments)
      user = User.authenticate(arguments)

      return {} unless user

      # Sets this user id in the client browser session
      session_user_set(user)
      verified = user.verified
      # Session maybe MO's way? in lieu of passing a token? - Nimmo
      token = Base64.encode64(user.login)
      # This is what the resolver returns:
      {
        token: token,
        user: user,
        verified: verified
      }
    rescue ActiveRecord::RecordNotFound
      raise(GraphQL::ExecutionError.new("user not found"))
    end
  end
end
