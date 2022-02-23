# frozen_string_literal: true

require("test_helper")
require("graphql_request_helper")

# Tests the GraphQL Controller and the most basic queries that reflect
# controller's `context` hash back to the JSON response, Visitor and Admin
# https://graphql-ruby.org/testing/integration_tests.html
class Mutations::HttpRequestTest < ActionDispatch::IntegrationTest
  include GraphQLRequestHelper

  def invalid_variables
    { "login" => "0" }
  end

  def valid_variables
    { "login" => users(:rolf).login }
  end

  def test_invalid_query
    do_graphql_request(user: nil, qry: nonsense_query)

    assert_equal("Field 'nonsense' doesn't exist on type 'Query'",
                 json["errors"][0]["message"], "Field does not exist")
  end

  def test_invalid_query_variables
    do_graphql_request(qry: user_query,
                       var: invalid_variables)

    assert_nil(json["data"], "Wrong variables")
  end

  def test_valid_query_variables
    do_graphql_request(qry: user_query,
                       var: valid_variables)

    assert_equal(users(:rolf).id, json["data"]["user"]["id"],
                 "Variable correctly parsed for query")
  end

  # Whether or not the controller correctly figures out no :current_user
  # Note this also tests the Visitor and Admin queries
  def test_check_no_token
    do_graphql_request(qry: visitor_query)

    assert_nil(json["data"]["visitor"],
               "Unauthenticated requests have no current_user")
    assert_equal(false, json["data"]["admin"],
                 "User not an admin")
  end

  # Refuse a token to unverified user
  def test_check_unverified_user_token
    do_graphql_request(user: users(:unverified), qry: visitor_query)

    assert_nil(json["data"]["visitor"],
               "Unverified user is not allowed as current_user")
    assert_equal(false, json["data"]["admin"],
                 "User not an admin")
  end

  # Whether or not the controller correctly figures out :in_admin_mode
  def test_check_non_admin_token
    # Rolf is not an admin.
    rolf = users(:rolf)

    do_graphql_request(user: rolf, qry: visitor_query)

    assert_equal(rolf.login, json["data"]["visitor"]["login"],
                 "Authenticated requests load the current_user")
    assert_equal(false, json["data"]["admin"],
                 "User not an admin")
  end

  def test_check_admin_token
    bill = users(:admin)

    do_graphql_request(user: bill, qry: visitor_query)

    assert_equal(true, json["data"]["admin"],
                 "Admin user is now in admin mode")
  end
end
