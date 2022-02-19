# frozen_string_literal: true

require("test_helper")
require("graphql_request_helper")

class Mutations::UserLoginTest < ActionDispatch::IntegrationTest
  include GraphQLRequestHelper

  def test_invalid_login_input
    do_graphql_request(qry: login_with_input, var: wrong_password)

    assert_nil(json.dig("data", "userLogin", "user"), "Invalid login")
    assert_nil(json["data"]["userLogin"]["token"], "Invalid login")
  end

  def test_valid_login_input
    do_graphql_request(qry: login_with_input, var: valid_password)

    assert_equal(users(:rolf).id,
                 json.dig("data", "userLogin", "user", "id"),
                 "Variable correctly parsed for query")

    token = json.dig("data", "userLogin", "token")

    do_graphql_request(user: users(:rolf), qry: visitor_query)

    assert_equal(users(:rolf).login,
                 json.dig("data", "visitor", "login"),
                 "Authenticated requests load the current_user")

    do_graphql_request(user: users(:rolf),
                       qry: user_query,
                       var: { login: users(:rolf).login },
                       token: json.dig("data", "userLogin", "token"))

    assert_equal(users(:rolf).email,
                 json.dig("data", "user", "email"),
                 "Authenticated user can load own email")
    assert_equal(users(:rolf).email_names_editor,
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
end
