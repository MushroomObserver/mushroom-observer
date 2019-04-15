require 'test_helper'

class PolicyControllerTest < ActionDispatch::IntegrationTest
  test "should get privacy" do
    get policy_privacy_url
    assert_response :success
  end

end
