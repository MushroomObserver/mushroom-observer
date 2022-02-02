require("test_helper")

class Mutations::HttpRequestTest < ActionDispatch::IntegrationTest
  def graphql_path
    "/graphql"
  end

  # https://graphql-ruby.org/testing/integration_tests.html
  def test_check_current_user
    query_string = "{ current_user { username } }"
    post(graphql_path, params: { query: query_string })
    json_response = JSON.parse(@response.body)
    assert_nil(json_response["data"]["viewer"], "Unauthenticated requests have no viewer")

    # This time, add some authentication to the HTTP request
    user = create(:user)
    post(graphql_path,
         params: { query: query_string },
         headers: { "Authorization" => "Bearer #{user.auth_token}" })

    json_response = JSON.parse(@response.body)
    assert_equal(user.username, json_response["data"]["viewer"], "Authenticated requests load the viewer")
    assert_equal("x", "y")
  end
end
