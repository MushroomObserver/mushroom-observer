# app/graphql/mutations/sign_in_mutation.rb

module Mutations
  class LogIn < Mutations::BaseMutation
    description "Login a user"

    input_object_class Types::LogInInput

    type Types::UserType

    def resolve(login: nil,
                password: nil)
      user = User.find_by!(login: login)
      return {} unless user
      return {} unless password == user.password

      token = Base64.encode64(user.login)
      {
        token: token,
        user: user
      }
    rescue ActiveRecord::RecordNotFound
      raise(GraphQL::ExecutionError.new("user not found"))
    end
  end
end
