# frozen_string_literal: true

require("test_helper")
require("graphql_request_helper")

class Mutations::UserLoginTest < ActionDispatch::IntegrationTest
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

  # def json
  #   JSON.parse(response.body)
  # end

  # def graphql_path
  #   "/graphql"
  # end

  # def do_graphql_request(user: nil, qry: nil, var: nil)
  #   token = Token.new(user_id: user&.id,
  #                     in_admin_mode: user&.admin).encrypt_to_header
  #   post(graphql_path, params: {
  #          query: qry || query,
  #          variables: var || variables
  #        }, headers: @headers)
  # end

  def test_invalid_login_input
    # post(graphql_path,
    #      params: { query: login_with_input,
    #                variables: wrong_password },
    #      headers: @headers)

    do_graphql_request(qry: login_with_input, var: wrong_password)

    puts("json.inspect")
    puts(json.inspect)

    assert_nil(json.dig("data", "userLogin", "user"), "Invalid login")
    assert_nil(json["data"]["userLogin"]["token"], "Invalid login")
  end

  def test_valid_login_input
    # post(graphql_path,
    #      params: { query: login_with_input,
    #                variables: valid_password },
    #      headers: @headers)

    # puts(users(:rolf).inspect)
    # user = User.authenticate(login: users(:rolf).login,
    #                          password: "testpassword")
    # puts("user direct")
    # puts(user.inspect)

    do_graphql_request(qry: login_with_input, var: valid_password)

    # json_response = JSON.parse(@response.body)
    # puts(json_response.inspect)

    assert_equal(users(:rolf).id,
                 json.dig("data", "userLogin", "user", "id"),
                 "Variable correctly parsed for query")

    # post(graphql_path,
    #      params: { query: visitor_query },
    #      headers: headers_with_auth(json.dig("data", "userLogin", "token")))
    # puts(json.inspect)
    token = json.dig("data", "userLogin", "token")
    # puts(token.inspect)

    do_graphql_request(user: users(:rolf), qry: visitor_query)

    # json_response = JSON.parse(@response.body)
    assert_equal(users(:rolf).login,
                 json.dig("data", "visitor", "login"),
                 "Authenticated requests load the current_user")

    do_graphql_request(user: users(:rolf),
                       qry: user_query,
                       var: { login: users(:rolf).login })
    #                    token: json.dig("data", "userLogin", "token"))

    # puts(json.inspect)
    assert_equal(users(:rolf).email,
                 json.dig("data", "user", "email"),
                 "Authenticated user can load own email")
    assert_equal(users(:rolf).email,
                 json.dig("data", "user", "emailNamesEditor"),
                 "Authenticated user can load own email_names_editor")
  end

  def login_with_input
    <<-GRAPHQL
    mutation userLogin($input: UserLoginInput!){
      userLogin( input: $input ){
        user {
          id,
          login
        },
        token
      }
    }
    GRAPHQL
  end

  def wrong_password
    {
      input: {
        login: users(:rolf).login,
        password: "0"
      }
    }
  end

  def valid_password
    {
      input: {
        login: users(:rolf).login,
        password: "testpassword"
      }
    }
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
