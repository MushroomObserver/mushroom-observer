# frozen_string_literal: true

require("test_helper")

module Queries
  class UserQueryTest < IntegrationTestCase
    def no_context
      {
        current_user: nil,
        in_admin_mode?: false
      }
    end

    def rolf_in_context
      {
        current_user: users(:rolf),
        in_admin_mode?: false
      }
    end

    def user_query_string
      <<-GRAPHQL
        query($id: Int, $login: String, $name: String){
          user(id: $id, login: $login, name: $name) {
            id
            name
            login
            email
          }
        }
      GRAPHQL
    end

    def test_find_user
      user = rolf

      result = MushroomObserverSchema.execute(
        user_query_string,
        variables: { id: user.id },
        context: no_context
      )
      user_result = result["data"]["user"]

      # Make sure the query worked
      assert_equal(user.id, user_result["id"])
      assert_equal(user.login, user_result["login"])

      result = MushroomObserverSchema.execute(
        user_query_string,
        variables: { login: user.login },
        context: no_context
      )
      user_result = result["data"]["user"]

      # Make sure the query worked
      assert_equal(user.login, user_result["login"])
      assert_equal(user.name, user_result["name"])

      result = MushroomObserverSchema.execute(
        user_query_string,
        variables: { name: user.name },
        context: no_context
      )
      user_result = result["data"]["user"]

      # Make sure the query worked
      assert_equal(user.id, user_result["id"])
      assert_equal(user.name, user_result["name"])
    end

    def test_email_visibility
      user = rolf
      result = MushroomObserverSchema.execute(
        user_query_string,
        variables: { login: user.login },
        context: rolf_in_context
      )
      user_result = result["data"]["user"]

      # Make sure Rolf can find his own email
      assert_equal(user.name, user_result["name"])
      assert_equal(user.email, user_result["email"])

      # Rolf queries for Mary Newbie by login
      result = MushroomObserverSchema.execute(
        user_query_string,
        variables: { login: users(:mary).login },
        context: rolf_in_context
      )
      user_result = result["data"]["user"]

      # Make sure Rolf can read Mary's name
      assert_equal(users(:mary).name, user_result["name"])
      # Make sure Rolf cannot read Mary's email address
      assert_nil(user_result["email"])
    end
  end
end
