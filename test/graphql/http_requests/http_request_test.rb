require("test_helper")

class Mutations::HttpRequestTest < ActionDispatch::IntegrationTest
  def graphql_path
    "/graphql"
  end

  # from an example on...
  # https://graphql-ruby.org/testing/integration_tests.html
  def test_check_current_user
    # Note - this is from an example, but current_user wouldn't even
    # be part of our query string. TBD what the original purpose was
    query_string = "{ current_user { username } }"
    post(graphql_path, params: { query: query_string })
    json_response = JSON.parse(@response.body)

    pp(json_response)

    assert_nil(json_response["context"]["current_user"], "Unauthenticated requests have no current_user")

    # This time, add some authentication to the HTTP request
    # No idea what the next line does in other test environments,
    # but it don't do noffin in ours
    user = create(:user)
    post(graphql_path,
         params: { query: query_string },
         headers: { "Authorization" => "Bearer #{user.auth_token}" })

    json_response = JSON.parse(@response.body)
    assert_equal(user.username, json_response["context"]["current_user"], "Authenticated requests load the current_user")
    assert_equal("x", "y")
  end
end
