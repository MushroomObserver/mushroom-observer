# frozen_string_literal: true

require("test_helper")

# test the helpers for Licenses controller
class LicensesHelperTest < ActionView::TestCase
  def test_license_updated_at
    assert_equal("nil",
                 license_updated_at(licenses(:ccnc25)))
    assert_equal("2013-03-02 04:45:03", # UTC
                 license_updated_at(licenses(:publicdomain)))
  end
end
