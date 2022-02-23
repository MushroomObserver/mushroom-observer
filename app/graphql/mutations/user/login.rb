# frozen_string_literal: true

# Authenticate and login a user, generating a token
module Mutations
  module User
    class Login < Mutations::BaseMutation
      description "Login a user"

      # RelayClassicMutation only accepts single input
      argument :input, Inputs::User::Login, required: true

      field :token, String, null: true
      field :user, Types::Models::UserType, null: true

      def resolve(input: nil)
        user = ::User.authenticate(login: input.login, password: input.password)

        return {} unless user

        raise(GraphQL::ExecutionError.new("User not verified")) unless
          user.verified

        user.update({ last_login: Time.zone.now })

        token = ::Token.new(user_id: user.id,
                            in_admin_mode: false,
                            remember_me: input.remember_me,
                            created: Time.zone.now).encrypt_to_header

        # This is what the resolver returns:
        {
          user: user, # For easier debugging
          token: token # Contains user_id
        }
      rescue ActiveRecord::RecordNotFound
        raise(GraphQL::ExecutionError.new("User not found"))
      end

      # https://www.howtographql.com/graphql-ruby/4-authentication/
    end
  end
end
