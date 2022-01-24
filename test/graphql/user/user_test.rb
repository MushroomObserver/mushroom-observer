# frozen_string_literal: true

require("test_helper")

class Mutations::UserTest < IntegrationTestCase # ActionDispatch::IntegrationTest # ActiveSupport::TestCase
  # def setup
  #   context = {
  #     session_user: context[:session_user]
  #   }
  # end

  # def test_find_user_by_id
  #   query_string = <<-GRAPHQL
  #     query($id: Int){
  #       user(id: $id) {
  #         name
  #         id
  #         email
  #         login
  #       }
  #     }
  #   GRAPHQL

  #   # user = rolf
  #   # user_id = MushroomObserverSchema.id_from_object(rolf, Types::Models::User, {})
  #   user_id = rolf.id

  #   result = MushroomObserverSchema.execute(query_string, variables: { id: user_id })
  #   user_result = result["data"]["user"]

  #   # Make sure the query worked
  #   assert_equal(user_id, user_result["id"])
  #   assert_equal("rolf", user_result["login"])
  # end

  # def good_signup_input
  #   {
  #     login: "Fred",
  #     email: "Fred@gmail.com",
  #     name: "Fred Waite",
  #     password: "123333",
  #     password_confirmation: "123333"
  #   }
  # end

  # def create_user(args = {}, context = {})
  #   Mutations::CreateUser.new(object: nil, field: nil, context: context).resolve(args)
  # end

  # def test_create_valid_user
  #   user = create_user(good_signup_input)

  #   assert(user.persisted?)
  #   assert_equal(user.name, "Fred Waite")
  #   assert_equal(user.email, "Fred@gmail.com")
  # end

  # def test_create_valid_user_integration
  #   query_string = <<-GRAPHQL
  #   mutation {
  #     createUser(
  #       input: {
  #         login: "Fred",
  #         email: "Fred@gmail.com",
  #         name: "Fred Waite",
  #         password: "123333",
  #         passwordConfirmation: "123333"
  #       }
  #     ) {
  #       id
  #       name
  #       email
  #     }
  #   }
  #   GRAPHQL

  #   user_result = MushroomObserverSchema.execute(query_string, context: {}, variables: {})
  #   # currently responds with a user not a node, or true. do we need to use connection?
  #   # puts(user_result.to_h)
  #   # {"data"=>{"createUser"=>{"id"=>1030180662, "name"=>"Fred Waite", "email"=>"Fred@gmail.com"}}}

  #   assert_equal("Fred Waite", user_result["data"]["createUser"]["name"])
  # end
end
