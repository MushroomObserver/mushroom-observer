# frozen_string_literal: true

module Mutations
  module User
    class Create < Mutations::BaseMutation
      description "Sign up a new user"

      # input_object_class Inputs::User::Create
      argument :input, Inputs::User::Create, required: true

      type Types::Models::UserType

      def resolve(**_input)
        user = User.create!(arguments)
        VerifyEmail.build(user).deliver_now
        # currently responds with a user not a node. do we need to use connection?
        # update the token?
        # token.provide_defaults
        # token.verified = nil
      end
    end
  end
end
