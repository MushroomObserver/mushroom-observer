# frozen_string_literal: true

require("test_helper")

class Mutations::HttpRequestTest < ActionDispatch::IntegrationTest
  # Need a user agent to get by MO's robot detector here. But neither
  # setting request.header nor Capybara.page.driver.header works here
  # https://stackoverflow.com/questions/39096779/set-custom-user-agent-on-rails-testing
  # def setup
  #   Capybara.page.driver.header("User-Agent", "iPadApp")
  # end

  def graphql_path
    "/graphql"
  end

  # Whether or not the controller correctly figures out :current_user
  # Note this also tests the Visitor query
  # https://graphql-ruby.org/testing/integration_tests.html
  def test_check_visitor_authentication
    query_string = "{ visitor { login } }"

    post(graphql_path,
         params: { query: query_string },
         headers: { "User-Agent" => "iPadApp" })

    json_response = JSON.parse(@response.body)

    assert_nil(json_response["data"],
               "Unauthenticated requests have no current_user")

    # This time, add some authentication to the HTTP request.
    rolf = User.find_by(login: "rolf")

    # maybe this should be a method of user class!
    # from graphql/mutations/user/login.rb
    token = rolf.create_graphql_token

    post(graphql_path,
         params: { query: query_string },
         headers: { "User-Agent" => "iPadApp",
                    "Authorization" => "Bearer #{token}" })

    json_response = JSON.parse(@response.body)

    assert_equal(rolf.login, json_response["data"]["visitor"]["login"],
                 "Authenticated requests load the current_user")
  end
end
