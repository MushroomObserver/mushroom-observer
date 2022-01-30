# frozen_string_literal: true

module Mutations::User
  class Logout < Mutations::BaseMutation
    description "Logout a user"

    # field :token, String, null: true
    # field :user, Types::Models::UserType, null: true

    def resolve
      # user = User.authenticate(arguments)

      unless context[:current_user]
        #   raise(GraphQL::ExecutionError.new("no user logged in"))
      end

      user = context[:current_user]

      # application_controller.rb#session_user_set
      # Sets this user id in the client browser session
      # session_user_set(user)
      verified = user.verified
      # Session maybe MO's way? in lieu of passing a token? - Nimmo
      token = Base64.encode64(user.id)
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
