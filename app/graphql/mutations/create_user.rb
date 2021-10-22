module Mutations
  class CreateUser < Mutations::BaseMutation
    description "Sign up a new user"

    input_object_class Inputs::CreateUserInput

    type Types::Models::User

    def resolve(**arguments)
      User.create!(arguments)

      # currently responds with a user not a node. do we need to use connection?
      # update the token?
      # token.provide_defaults
      # token.verified = nil
    end
  end
end
