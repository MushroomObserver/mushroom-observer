# frozen_string_literal: true

require("test_helper")

class LicenseTest < UnitTestCase
  def test_available_names_and_ids_nothing_chosen
    names_and_ids = License.available_names_and_ids

    assert_equal(License.current.count, names_and_ids.length)
    names_and_ids.each do |(_name, id)|
      license = License.find(id)
      assert_not(
        license.deprecated?,
        "#{license.id}, #{license.display_name}, should not be deprecated."
      )
    end
  end

  def test_available_names_and_ids_deprecated_chosen
    chosen = licenses(:ccnc25)
    assert(chosen.deprecated?, "Test needs deprecated License fixture")

    names_and_ids = License.available_names_and_ids(chosen)

    assert_equal(License.current.count + 1, names_and_ids.length)
  end

  def test_available_names_and_ids_nondeprecated_chosen
    chosen = licenses(:ccbync)
    assert_not(chosen.deprecated?, "Test needs nondeprecated License fixture")

    names_and_ids = License.available_names_and_ids(chosen)

    assert_equal(License.current.count, names_and_ids.length)
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

  def test_abbreviation
    assert_equal("CC-BY-NC-SA", licenses(:ccnc30).abbreviation,
                 "Instance method should return CC slug uppercased")
    assert_equal("CC-BY-SA", licenses(:ccwiki30).abbreviation,
                 "Instance method should handle by-sa slug")
    assert_equal("CC0", licenses(:publicdomain).abbreviation,
                 "Instance method should return CC0 for public domain")
  end

  def test_abbreviation_for
    assert_equal("CC-BY-NC-SA",
                 License.abbreviation_for(licenses(:ccnc30).url),
                 "Class method should derive abbreviation from url")
    assert_equal("CC0",
                 License.abbreviation_for(licenses(:publicdomain).url),
                 "Class method should return CC0 for public domain url")
    assert_equal("CC0",
                 License.abbreviation_for(licenses(:legacy_publicdomain).url),
                 "Class method should return CC0 for legacy public domain url")
  end

  def test_rights_for
    license = licenses(:ccnc30)
    expected = "© Mary Newbie CC-BY-NC-SA #{license.url}"
    assert_equal(expected, license.rights_for("Mary Newbie"),
                 "Instance method should format © name abbreviation url")
  end

  def test_rights_string
    license = licenses(:ccnc30)
    expected = "© Mary Newbie CC-BY-NC-SA #{license.url}"
    assert_equal(expected,
                 License.rights_string("Mary Newbie", license.url),
                 "Class method should format © name abbreviation url")
  end

  def test_rights_string_legacy_public_domain
    license = licenses(:legacy_publicdomain)
    expected = "© Rolf Singer CC0 #{license.url}"
    assert_equal(
      expected,
      License.rights_string("Rolf Singer", license.url),
      "rights_string should use CC0 and canonical url for legacy public domain"
    )
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
