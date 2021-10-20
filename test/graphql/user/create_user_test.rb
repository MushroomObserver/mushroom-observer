# require("test_helper")

# class Mutations::CreateUserTest < ActiveSupport::TestCase
#   # def setup
#     # context = {
#     #   session_user: session[:session_user],
#     # }
#     # def perform(args = {})
#     #   Mutations::CreateUser.new(object: nil, field: nil, context: {}).resolve(args)
#     # end
#   # end

#   # def create_valid_user
#   #   user = perform(
#   #     input: {
#   #       login: "Fred",
#   #       email: "Fred@gmail.com",
#   #       name: "Fred Waite",
#   #       password: "123333",
#   #       passwordConfirmation: "123333"
#   #     }
#   #   )

#   #   assert user.persisted?
#   #   assert_equal user.name, "Fred Waite"
#   #   assert_equal user.email, "Fred@gmail.com"
#   # end

#   def create_valid_user_integration
#     query_string = <<-GRAPHQL
#     mutation {
#       create_user(
#         input: {
#           login: "Fred",
#           email: "Fred@gmail.com",
#           name: "Fred Waite",
#           password: "123333",
#           passwordConfirmation: "123333"
#         }
#       ) {
#         id
#         name
#         email
#       }
#     }
#     GRAPHQL

#   user_result = MushroomObserverSchema.execute(query_string, context: {}, variables: {})

#   puts result
#   assert_equal true, user_result["data"]["node"]
#   end

# end
