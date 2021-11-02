# frozen_string_literal: true

# frozen_string_literal: true

module Mutations::User
  class Login < Mutations::BaseMutation
    description "Login a user"

    input_object_class Inputs::User::Login

    field :token, String, null: true
    field :user, Types::Models::User, null: true

    def resolve(**arguments)
      user = User.authenticate(arguments.except(:remember_me))

      return {} unless user

      # verified = user.verified
      # admin = user.admin

      now = Time.zone.now
      args = {
        last_login: now,
        updated_at: now
      }
      user.update(args)

      # https://www.howtographql.com/graphql-ruby/4-authentication/
      crypt = ActiveSupport::MessageEncryptor.new(Rails.application.credentials.secret_key_base.byteslice(0..31))
      token = crypt.encrypt_and_sign("user-id:#{user.id}")

      context[:session][:token] = token

      # This is what the resolver returns:
      {
        user: user, # For debugging
        token: token
      }
    rescue ActiveRecord::RecordNotFound
      raise(GraphQL::ExecutionError.new("user not found"))
    end
  end
end
