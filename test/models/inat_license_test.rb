# frozen_string_literal: true

require("test_helper")

# test mapping iNat license_code to MO license_id
# https://github.com/inaturalist/inaturalist/blob/main/app/models/shared/license_module.rb
class INatLicenseTest < UnitTestCase
  def test_inat_cc_license
    assert_equal(licenses(:ccnc30), INat::License.new("cc-by-nc-sa").mo_license)
  end

  def test_inat_public_domain
    assert_equal(licenses(:publicdomain), INat::License.new("cc0").mo_license)
  end

  def test_inat_unlicensed
    license_display_name =
      "Creative Commons Attribution Non-commercial ShareAlike v4.0"
    # The narrowest available license in the db, but it's not a fixture
    ccbyncnd = ::License.create(
      display_name: license_display_name,
      url: "https://creativecommons.org/licenses/by-nc-sa/4.0/",
      deprecated: false
    )

    assert_equal(
      ::License.narrowest_available, INat::License.new(nil).mo_license,
      "iNat All Rights Reserved should map to MO #{ccbyncnd[:display_name]}"
    )
  end
end
