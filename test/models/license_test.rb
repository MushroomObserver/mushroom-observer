# frozen_string_literal: true

require("test_helper")

class LicenseTest < UnitTestCase
  def test_current_names_and_ids
    names_and_ids = License.current_names_and_ids
    assert_equal(4, names_and_ids.length)
    names_and_ids.each do |(_name, id)|
      license = License.find(id)
      assert_not(
        license.deprecated,
        "#{license.id}, #{license.display_name}, should not be deprecated."
      )
    end
  end

  def test_current_names_and_ids_ccnc25
    names_and_ids = License.current_names_and_ids(licenses(:ccnc25))
    assert_equal(5, names_and_ids.length)
  end

  def test_in_use
    assert(licenses(:ccnc30).in_use?)
    assert_not(licenses(:unused).in_use?)
  end

  def test_attribute_duplicated?
    ccnc25 = licenses(:ccnc25)

    license = License.new(display_name: ccnc25.display_name,
                          code: "anything", url: "anything")
    assert(license.attribute_duplicated?)

    license = License.new(display_name: "anything",
                          code: ccnc25.code, url: "anything")
    assert(license.attribute_duplicated?)

    license = License.new(display_name: "anything",
                          code: "anything", url: ccnc25.url)
    assert(license.attribute_duplicated?)

    assert_not(ccnc25.attribute_duplicated?)
  end

  def test_license_badge_url
    assert_equal("https://licensebuttons.net/l/by-nc-sa/3.0/88x31.png",
                 licenses(:ccnc30).badge_url)
  end
end
