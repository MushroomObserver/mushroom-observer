# frozen_string_literal: true

require("test_helper")

# test mapping iNat license_code to MO license_id
class InatLicenseTest < UnitTestCase
  def test_mapped_license
    assert_equal(licenses(:ccnc30), InatLicense.new("cc-by-nc-sa").mo_license)
  end

  def test_public_domain
    assert_equal(licenses(:publicdomain), InatLicense.new("cc0").mo_license)
  end

  def test_unlicensed
    assert_nil(InatLicense.new.mo_license)
  end
end
