# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Contributors
#  contributors_controller
# ------------------------------------------------------------
class ContributorsControllerTest < FunctionalTestCase
  def test_page_load
    login
    get(:index)
    assert_template("contributors/_contributor")
  end
end
