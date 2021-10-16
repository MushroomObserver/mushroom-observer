module Mutations
  class CreateUser < Mutations::BaseMutation
    description "Sign Up a new user"

    input_object_class Types::CreateUserInput

    type Types::UserType

    def resolve(**arguments)
      User.create!(arguments)
    end
  end
end
