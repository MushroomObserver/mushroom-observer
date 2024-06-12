# frozen_string_literal: true

require("test_helper")

class LicenseTest < UnitTestCase
  def test_current_names_and_ids
    names_and_ids = License.current_names_and_ids
    assert_equal(5, names_and_ids.length)
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
    assert_equal(6, names_and_ids.length)
  end

  def test_in_use
    assert(licenses(:ccnc30).in_use?)
    assert_not(licenses(:unused).in_use?)
  end

  def test_attribute_duplicated?
    ccnc25 = licenses(:ccnc25)

    license = License.new(display_name: ccnc25.display_name, url: "anything")
    assert(license.attribute_duplicated?)

    license = License.new(display_name: "anything", url: ccnc25.url)
    assert(license.attribute_duplicated?)

    assert_not(ccnc25.attribute_duplicated?)
  end

  def test_license_badge_url
    assert_equal("https://licensebuttons.net/l/by-nc-sa/3.0/88x31.png",
                 licenses(:ccnc30).badge_url)
  end

  def test_preferred
    preferred_license = License.preferred
    assert(preferred_license.preferred?)

    License.where.not(id: preferred_license.id).find_each do |lic|
      assert_not(lic.preferred?, "There should be only one preferred license.")
    end
  end

  def test_text_name
    license = licenses(:ccnc25)
    assert_equal(license.display_name, license.text_name)
  end

  def test_copyright_text
    year = 2024
    name = "Jan Borovicka"

    assert_equal(licenses(:ccnc25).copyright_text(year, name),
                 "Copyright &copy; #{year} #{name}")
    assert_equal(licenses(:publicdomain).copyright_text(year, name),
                 "Public Domain by #{name}")
  end
end
