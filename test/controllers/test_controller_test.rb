# frozen_string_literal: true

require("test_helper")

# Controller tests for info pages
class TestControllerTest < FunctionalTestCase
  def test_tester
    get(:index)
    assert_equal(200, @response.status)
  end
end
