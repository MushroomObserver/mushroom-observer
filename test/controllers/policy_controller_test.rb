# frozen_string_literal: true

require("test_helper")

class PolicyControllerTest < FunctionalTestCase
  def test_privacy
    get(:privacy)

    assert_response(:success)
    assert_head_title(:privacy_title.l)
  end
end
