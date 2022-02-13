# frozen_string_literal: true

require("test_helper")

class Mutations::HttpRequestTest < ActionDispatch::IntegrationTest
  # Tests the GraphQL Controller and the most basic queries that reflect
  # controller's `context` hash back to the JSON response, Visitor and Admin
  # https://graphql-ruby.org/testing/integration_tests.html

  # Setup: We need to set a user agent to get by MO's robot detector here.
  # Neither setting request.header nor Capybara.page.driver.header works?
  # https://stackoverflow.com/questions/39096779/set-custom-user-agent-on-rails-testing

  def setup
    @headers = { "User-Agent" => "iPadApp" }
  end

  def headers_with_auth(token)
    return @headers unless token

    headers = @headers
    headers["Authorization"] = "Bearer #{token}"
    headers
  end

  def graphql_path
    "/graphql"
  end

  def query_string
    "{ visitor { login }, admin }"
  end

  def invalid_query_string
    "{ nonsense }"
  end

  def query_with_variables
    "query findRolf($login: String!){ user( login: $login ){ login, id } }"
  end

  def invalid_variables
    { "login" => "0" }
  end

  def valid_variables
    { "login" => users(:rolf).login }
  end

  def test_invalid_query_string
    post(graphql_path,
         params: { query: invalid_query_string },
         headers: @headers)

    json_response = JSON.parse(@response.body)
    assert_equal("Field 'nonsense' doesn't exist on type 'Query'",
                 json_response["errors"][0]["message"], "Field does not exist")
  end

  def test_invalid_query_variables
    post(graphql_path,
         params: { query: query_with_variables, variables: invalid_variables },
         headers: @headers)

    json_response = JSON.parse(@response.body)
    assert_nil(json_response["data"], "Wrong variables")
  end

  def test_valid_query_variables
    post(graphql_path,
         params: { query: query_with_variables, variables: valid_variables },
         headers: @headers)

    json_response = JSON.parse(@response.body)
    assert_equal(users(:rolf).id, json_response["data"]["user"]["id"],
                 "Variable correctly parsed for query")
  end

  # Whether or not the controller correctly figures out no :current_user
  # Note this also tests the Visitor and Admin queries
  def test_check_no_token
    post(graphql_path,
         params: { query: query_string },
         headers: @headers)

    json_response = JSON.parse(@response.body)

    assert_nil(json_response["data"]["visitor"],
               "Unauthenticated requests have no current_user")
    assert_equal(false, json_response["data"]["admin"],
                 "User not an admin")
  end

  # Refuse a token to unverified user
  def test_check_unverified_user_token
    user = users(:unverified)
    token = Token.new(user_id: user.id,
                      in_admin_mode: user.admin).encrypt_to_header

    post(graphql_path,
         params: { query: query_string },
         headers: headers_with_auth(token))

    json_response = JSON.parse(@response.body)

    assert_nil(json_response["data"]["visitor"],
               "Unverified user is not allowed as current_user")
    assert_equal(false, json_response["data"]["admin"],
                 "User not an admin")
  end

  # Whether or not the controller correctly figures out :in_admin_mode
  def test_check_non_admin_token
    # This time, add some authentication to the HTTP request.
    # Rolf is not an admin.
    rolf = users(:rolf)
    token = Token.new(user_id: rolf.id,
                      in_admin_mode: rolf.admin).encrypt_to_header

    post(graphql_path,
         params: { query: query_string },
         headers: headers_with_auth(token))

    json_response = JSON.parse(@response.body)

    assert_equal(rolf.login, json_response["data"]["visitor"]["login"],
                 "Authenticated requests load the current_user")
    assert_equal(false, json_response["data"]["admin"],
                 "User not an admin")
  end

  def test_check_admin_token
    bill = users(:admin)
    token = Token.new(user_id: bill.id,
                      in_admin_mode: bill.admin).encrypt_to_header

    post(graphql_path,
         params: { query: query_string },
         headers: headers_with_auth(token))

    json_response = JSON.parse(@response.body)

    assert_equal(true, json_response["data"]["admin"],
                 "Admin user is now in admin mode")
  end
end
