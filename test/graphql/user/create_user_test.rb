# frozen_string_literal: true

require("test_helper")

class Mutations::CreateUserTest < IntegrationTestCase # ActionDispatch::IntegrationTest # ActiveSupport::TestCase
  # def setup
  #   context = {
  #     session_user: context[:session_user]
  #   }
  # end

  def perform(args = {}, context = {})
    Mutations::CreateUser.new(object: nil, field: nil, context: context).resolve(args)
  end

  # def test_create_valid_user
  #   user = perform(
  #     input: {
  #       login: "Fred",
  #       email: "Fred@gmail.com",
  #       name: "Fred Waite",
  #       password: "123333",
  #       passwordConfirmation: "123333"
  #     }
  #   )

  #   assert(user.persisted?)
  #   assert_equal(user.name, "Fred Waite")
  #   assert_equal(user.email, "Fred@gmail.com")
  # end

  def test_find_user_by_id
    query_string = <<-GRAPHQL
      query($id: ID!){
        node(id: $id) {
          ... on User {
            name
            id
            email
          }
        }
      }
    GRAPHQL

    user = rolf
    user_id = MushroomObserverSchema.id_from_object(user, Types::Models::User, {})
    result = MushroomObserverSchema.execute(query_string, variables: { id: user_id })

    user_result = result["data"]["node"]
    # Make sure the query worked
    assert_equal(user_id, user_result["id"])
    assert_equal("rolf", user_result["login"])
  end

  def test_create_valid_user_integration
    query_string = <<-GRAPHQL
    mutation {
      create_user(
        input: {
          login: "Fred",
          email: "Fred@gmail.com",
          name: "Fred Waite",
          password: "123333",
          passwordConfirmation: "123333"
        }
      ) {
        id
        name
        email
      }
    }
    GRAPHQL

    user_result = MushroomObserverSchema.execute(query_string, context: {}, variables: {})

    puts(user_result)
    assert_equal(true, user_result["data"]["node"])
  end
end
