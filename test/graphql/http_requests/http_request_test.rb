# frozen_string_literal: true

require("test_helper")
require("graphql_request_helper")

class Mutations::HttpRequestTest < ActionDispatch::IntegrationTest
  include GraphQLRequestHelper
  # Tests the GraphQL Controller and the most basic queries that reflect
  # controller's `context` hash back to the JSON response, Visitor and Admin
  # https://graphql-ruby.org/testing/integration_tests.html

  # Setup: We need to set a user agent to get by MO's robot detector here.
  # Neither setting request.header nor Capybara.page.driver.header works?
  # https://stackoverflow.com/questions/39096779/set-custom-user-agent-on-rails-testing

  # def setup
  #   @headers = { "User-Agent" => "iPadApp" }
  # end

  # def headers_with_auth(token)
  #   return @headers unless token

  #   headers = @headers
  #   headers["Authorization"] = "Bearer #{token}"
  #   headers
  # end

  # def graphql_path
  #   "/graphql"
  # end

  # def visitor_query
  #   "{ visitor { login }, admin }"
  # end

  # def invalid_query
  #   "{ nonsense }"
  # end

  # def user_query_by_login
  #   "query findRolf($login: String!){ user( login: $login ){ login, id } }"
  # end

  def invalid_variables
    { "login" => "0" }
  end

  def valid_variables
    { "login" => users(:rolf).login }
  end

  def test_invalid_query
    # post(graphql_path,
    #      params: { query: invalid_query },
    #      headers: @headers)

    do_graphql_request(user: nil, qry: nonsense_query)

    # json_response = JSON.parse(@response.body)
    assert_equal("Field 'nonsense' doesn't exist on type 'Query'",
                 json["errors"][0]["message"], "Field does not exist")
  end

  def test_invalid_query_variables
    # post(graphql_path,
    #      params: { query: user_query_by_login, variables: invalid_variables },
    #      headers: @headers)

    do_graphql_request(qry: user_query,
                       var: invalid_variables)

    # json_response = JSON.parse(@response.body)
    assert_nil(json["data"], "Wrong variables")
  end

  def test_valid_query_variables
    # post(graphql_path,
    #      params: { query: user_query_by_login, variables: valid_variables },
    #      headers: @headers)

    do_graphql_request(qry: user_query,
                       var: valid_variables)

    # json_response = JSON.parse(@response.body)
    assert_equal(users(:rolf).id, json["data"]["user"]["id"],
                 "Variable correctly parsed for query")
  end

  # Whether or not the controller correctly figures out no :current_user
  # Note this also tests the Visitor and Admin queries
  def test_check_no_token
    # post(graphql_path,
    #      params: { query: visitor_query },
    #      headers: @headers)

    do_graphql_request(qry: visitor_query)

    # json_response = JSON.parse(@response.body)

    assert_nil(json["data"]["visitor"],
               "Unauthenticated requests have no current_user")
    assert_equal(false, json["data"]["admin"],
                 "User not an admin")
  end

  # Refuse a token to unverified user
  def test_check_unverified_user_token
    # user = users(:unverified)
    # token = Token.new(user_id: user.id,
    #                   in_admin_mode: user.admin).encrypt_to_header

    # post(graphql_path,
    #      params: { query: visitor_query },
    #      headers: headers_with_auth(token))

    # json_response = JSON.parse(@response.body)
    do_graphql_request(user: users(:unverified), qry: visitor_query)

    assert_nil(json["data"]["visitor"],
               "Unverified user is not allowed as current_user")
    assert_equal(false, json["data"]["admin"],
                 "User not an admin")
  end

  # Whether or not the controller correctly figures out :in_admin_mode
  def test_check_non_admin_token
    # This time, add some authentication to the HTTP request.
    # Rolf is not an admin.
    rolf = users(:rolf)
    # token = Token.new(user_id: rolf.id,
    #                   in_admin_mode: rolf.admin).encrypt_to_header

    # post(graphql_path,
    #      params: { query: visitor_query },
    #      headers: headers_with_auth(token))

    # json_response = JSON.parse(@response.body)
    do_graphql_request(user: rolf, qry: visitor_query)

    assert_equal(rolf.login, json["data"]["visitor"]["login"],
                 "Authenticated requests load the current_user")
    assert_equal(false, json["data"]["admin"],
                 "User not an admin")
  end

  def test_check_admin_token
    bill = users(:admin)
    # token = Token.new(user_id: bill.id,
    #                   in_admin_mode: bill.admin).encrypt_to_header

    # post(graphql_path,
    #      params: { query: visitor_query },
    #      headers: headers_with_auth(token))

    # json_response = JSON.parse(@response.body)
    do_graphql_request(user: bill, qry: visitor_query)

    assert_equal(true, json["data"]["admin"],
                 "Admin user is now in admin mode")
  end
end
