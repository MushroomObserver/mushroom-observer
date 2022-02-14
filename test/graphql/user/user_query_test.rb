# frozen_string_literal: true

require("test_helper")

module Queries
  class UserQueryTest < IntegrationTestCase
    # def setup
    #   context = {
    #     session_user: context[:session_user]
    #   }
    # end

    def test_find_user_by_id
      query_string = <<-GRAPHQL
        query($id: Int){
          user(id: $id) {
            name
            id
            email
            login
          }
        }
      GRAPHQL

      user = rolf

      result = MushroomObserverSchema.execute(
        query_string, variables: { id: user.id }
      )
      user_result = result["data"]["user"]

      # Make sure the query worked
      assert_equal(user.id, user_result["id"])
      assert_equal(user.login, user_result["login"])
    end

    def test_find_user_by_login
      query_string = <<-GRAPHQL
        query($login: String){
          user(login: $login) {
            name
            id
            email
            login
          }
        }
      GRAPHQL

      user = rolf

      result = MushroomObserverSchema.execute(
        query_string, variables: { login: user.login }
      )
      user_result = result["data"]["user"]

      # Make sure the query worked
      assert_equal(user.login, user_result["login"])
      assert_equal(user.name, user_result["name"])
    end

    def test_find_user_by_email
      query_string = <<-GRAPHQL
        query($email: String){
          user(email: $email) {
            name
            id
            email
            login
          }
        }
      GRAPHQL

      user = rolf

      result = MushroomObserverSchema.execute(
        query_string, variables: { email: user.email }
      )
      user_result = result["data"]["user"]

      # Make sure the query worked
      assert_equal(user.email, user_result["email"])
      assert_equal(user.name, user_result["name"])
    end

    def test_find_user_by_name
      query_string = <<-GRAPHQL
        query($name: String){
          user(name: $name) {
            name
            id
            email
            login
          }
        }
      GRAPHQL

      user = rolf

      result = MushroomObserverSchema.execute(
        query_string, variables: { name: user.name }
      )
      user_result = result["data"]["user"]

      # Make sure the query worked
      assert_equal(user.name, user_result["name"])
      assert_equal(user.email, user_result["email"])
    end

    # Note: https://graphql-ruby.org/authorization/overview.html
    # Add authorization control to some fields in graphql/types/models/User.rb
    # that only the user should get, and put one of those in this query string
    # This query works OK - auth not currently required for any user field
    # query_string = "{ user( login: \"rolf\" ){ id name email password } }"
  end
end
