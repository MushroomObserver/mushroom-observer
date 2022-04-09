# frozen_string_literal: true

require("test_helper")
require("graphql_execute_helper")

module Queries
  class UserQueryTest < IntegrationTestCase
    include GraphQLExecuteHelper

    def test_find_user
      user = users(:rolf)

      json = do_graphql(qry: user_query, var: { id: user.id })
      user_result = json.dig("data", "user")

      # Make sure the query worked
      assert_equal(user.id, user_result["id"])
      assert_equal(user.login, user_result["login"])

      json = do_graphql(qry: user_query, var: { login: user.login })
      user_result = json.dig("data", "user")

      # Make sure the query worked
      assert_equal(user.login, user_result["login"])
      assert_equal(user.name, user_result["name"])

      json = do_graphql(qry: user_query, var: { name: user.name })
      user_result = json.dig("data", "user")

      # Make sure the query worked
      assert_equal(user.id, user_result["id"])
      assert_equal(user.name, user_result["name"])
    end

    def test_email_visibility
      user = rolf
      json = do_graphql(user: user, qry: user_query, var: { login: user.login })
      user_result = json.dig("data", "user")

      # Make sure Rolf can find his own email and preferences
      assert_equal(user.name, user_result["name"])
      assert_equal(user.email, user_result["email"])
      assert_equal(user.email_names_editor, user_result["emailNamesEditor"])

      # Rolf queries for Mary Newbie by login
      json = do_graphql(user: user, qry: user_query,
                        var: { login: users(:mary).login })
      user_result = json.dig("data", "user")

      # Make sure Rolf can read Mary's name or preferences
      assert_equal(users(:mary).name, user_result["name"])
      # Make sure Rolf cannot read Mary's email address
      assert_nil(user_result["email"])
      assert_nil(user_result["emailNamesEditor"])
    end
  end
end
