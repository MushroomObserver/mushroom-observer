# frozen_string_literal: true

require("test_helper")

# Test things that are untestable in integration tests
class LicensesIntegrationTest < CapybaraIntegrationTestCase
  def test_link_to_licenses
    login(users(:admin))
    assert_no_selector(:link, text: :LICENSES.l)

    first("button", text: "Turn on Admin Mode").click
    assert_selector(:link, text: :LICENSES.l)
  end
end
