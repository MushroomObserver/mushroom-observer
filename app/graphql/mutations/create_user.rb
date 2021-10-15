module Mutations
  class CreateUser < BaseMutation
    # often we will need input types for specific mutation
    # in those cases we can define those input types in the mutation class itself
    # class AuthProviderSignupData < Types::BaseInputObject
    argument :name, String, required: true
    # argument :credentials, Types::SignInCredentials, required: false
    argument :email, String, required: true
    argument :password, String, required: true
    # end

    # argument :auth_provider, AuthProviderSignupData, required: false

    type Types::UserType

    def resolve(name: nil, auth_provider: nil)
      User.create!(
        name: name,
        email: email,
        password: password
      )
    end
  end
end
