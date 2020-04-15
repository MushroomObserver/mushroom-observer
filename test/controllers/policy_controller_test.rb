require "test_helper"

class PolicyControllerTest < IntegrationTestCase
  test "should get privacy" do
    get policy_privacy_url
    assert_response :success
  end
end
