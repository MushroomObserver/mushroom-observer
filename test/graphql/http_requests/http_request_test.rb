require("test_helper")

class Mutations::HttpRequestTest < ActionDispatch::IntegrationTest
  def graphql_path
    "/graphql"
  end

  # from an example on...
  # https://graphql-ruby.org/testing/integration_tests.html
  def test_check_user_field_authorization
    # What we need to test here is whether or not the controller shows fields
    # requiring authorization.

    # We're not testing the context object's :current_user, which is
    # internal to the controller.

    # TODO: https://graphql-ruby.org/authorization/overview.html
    # Add authorization control to some fields in graphql/types/models/User.rb
    # that only the user should get, and put one of those in this query string
    # This query works OK - auth not currently required for any user field
    query_string = "{ user( login: \"rolf\" ){ id name email bonuses } }"

    # # https://stackoverflow.com/questions/39096779/set-custom-user-agent-on-rails-testing
    # # page.driver.header("User-Agent", "Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405")
    # post(graphql_path,
    #      params: { query: query_string },
    #      headers: { "User-Agent" => "iPadApp" })

    # json_response = JSON.parse(@response.body)

    # pp("json_response")
    # pp(json_response)

    # assert_nil(json_response["data"]["user"], "Unauthenticated requests have no current_user")

    # This time, add some authentication to the HTTP request. However,
    # this isn't how we're doing auth presently on MO's graphql_controller.
    # No idea what the next line does in other test environments,
    # but it don't do noffin in ours
    # user = create(:user)
    user = User.find_by(login: "rolf")
    pp("user")
    pp(user)

    # maybe this should be a method of user class!
    # from graphql/mutations/user/login.rb
    crypt = ActiveSupport::MessageEncryptor.new(
      Rails.application.credentials.secret_key_base.byteslice(0..31)
    )
    token = crypt.encrypt_and_sign("user-id:#{user.id}")

    post(graphql_path,
         params: { query: query_string },
         headers: { "User-Agent" => "iPadApp",
                    "Authorization" => "Bearer #{token}" })

    json_response = JSON.parse(@response.body)

    pp("json_response")
    pp(json_response)

    assert_equal(user.login, json_response["context"]["current_user"], "Authenticated requests load the current_user")
  end
end
