require("test_helper")

class Mutations::HttpRequestTest < ActionDispatch::IntegrationTest
  def graphql_path
    "/graphql"
  end

  # from an example on...
  # https://graphql-ruby.org/testing/integration_tests.html
  def test_check_current_user
    # OK, this query works - auth not currently required for any user field
    # TBD what a non-authorized query would be
    query_string = "{ user( login: \"rolf\" ){ id name email bonuses } }"

    # https://stackoverflow.com/questions/39096779/set-custom-user-agent-on-rails-testing
    # page.driver.header("User-Agent", "Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405")
    post(graphql_path,
         params: { query: query_string },
         headers: { "User-Agent" => "iPadApp" })

    json_response = JSON.parse(@response.body)

    pp("json_response")
    pp(json_response)

    assert_nil(json_response["data"]["user"], "Unauthenticated requests have no current_user")

    # This time, add some authentication to the HTTP request. However,
    # this isn't how we're doing auth presently on MO's graphql_controller.
    # No idea what the next line does in other test environments,
    # but it don't do noffin in ours
    # user = create(:user)
    # post(graphql_path,
    #      params: { query: query_string },
    #      headers: { "Authorization" => "Bearer #{user.auth_token}" })

    # json_response = JSON.parse(@response.body)
    # assert_equal(user.username, json_response["context"]["current_user"], "Authenticated requests load the current_user")
    # assert_equal("x", "y")
  end
end
