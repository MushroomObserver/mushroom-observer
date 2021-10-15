# app/graphql/mutations/sign_in_mutation.rb

module Mutations
  class SignIn < Mutations::BaseMutation
    argument :email, String, required: true

    field :token, String, null: true
    field :user, Types::UserType, null: true

    def resolve(email:)
      user = User.find_by!(email: email)
      return {} unless user

      token = Base64.encode64(user.email)
      {
        token: token,
        user: user
      }
    rescue ActiveRecord::RecordNotFound
      raise(GraphQL::ExecutionError.new("user not found"))
    end
  end
end
