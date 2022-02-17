# frozen_string_literal: true

require("test_helper")

class Mutations::UserLoginTest < ActionDispatch::IntegrationTest
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

  def visitor_query
    "{ visitor { login }, admin }"
  end

  def invalid_query_string
    "{ nonsense }"
  end

  def login_with_input
    "mutation userLogin($input: UserLoginInput!){ "\
    "userLogin( input: $input ){ user { id, login }, token } }"
  end

  def wrong_password
    { "input" => { "login" => users(:rolf).login, "password" => "0" } }
  end

  def valid_password
    { "input" => { "login" => users(:rolf).login,
                   "password" => users(:rolf).password } }
  end

  def test_invalid_login_input
    post(graphql_path,
         params: { query: login_with_input, variables: wrong_password },
         headers: @headers)

    json_response = JSON.parse(@response.body)
    puts(json_response.inspect)

    assert_nil(json_response["data"]["userLogin"]["user"], "Invalid login")
    assert_nil(json_response["data"]["userLogin"]["token"], "Invalid login")
  end

  def test_valid_login_input
    post(graphql_path,
         params: { query: login_with_input,
                   variables: valid_password },
         headers: @headers)

    json_response = JSON.parse(@response.body)
    puts(json_response.inspect)
    assert_equal(users(:rolf).id,
                 json_response["data"]["userLogin"]["user"]["id"],
                 "Variable correctly parsed for query")

    # post(graphql_path,
    #      params: { query: visitor_query },
    #      headers: headers_with_auth(json_response["data"]["token"]))

    # json_response = JSON.parse(@response.body)
    # assert_equal(rolf.login, json_response["data"]["visitor"]["login"],
    #              "Authenticated requests load the current_user")
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
end
