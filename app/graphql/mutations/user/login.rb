# frozen_string_literal: true

module Mutations::User
  class Login < Mutations::BaseMutation
    description "Login a user"

    # RelayClassicMutation only accepts single input
    # input_object_class Inputs::User::Login
    argument :input, Inputs::User::Login, required: true

    field :token, String, null: true
    field :user, Types::Models::UserType, null: true

    # was resolve(**arguments), authenticate(arguments.except(:remember_me))
    # def resolve(credentials: nil, token: nil, user: nil)
    def resolve(input: nil, token: nil, user: nil)
      user = User.authenticate(**input)

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

      # I believe i'm abandoning this, just keeping it for tests.
      # Session auth would be possible if the Svelte app were hosted
      # on the same domain... but we need something more versatile.
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
