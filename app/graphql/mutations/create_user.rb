module Mutations
  class CreateUser < Mutations::BaseMutation
    description "Sign Up a new user"

    input_object_class Types::SignUpInput

    type Types::UserType

    def resolve(login: nil,
                name: nil,
                email: nil,
                password: nil,
                password_confirmation: nil)
      User.create!(
        login: login,
        name: name,
        email: email,
        password: password,
        password_confirmation: password_confirmation
      )
    end
  end
end
