module Mutations
  class CreateUser < Mutations::BaseMutation
    description "Sign Up a new user"

    input_object_class Inputs::CreateUserInput

    type Types::Models::User

    def resolve(**arguments)
      User.create!(arguments)

      # update the token?
      # token.provide_defaults
      # token.verified = nil
    end
  end
end
