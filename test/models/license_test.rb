# encoding: utf-8
require "test_helper"

class LicenseTest < UnitTestCase
  def test_current_names_and_ids
    names_and_ids = License.current_names_and_ids
    assert_equal(3, names_and_ids.length)
    names_and_ids.each do |name, id|
      license = License.find(id)
      refute(license.deprecated,
             "#{license.id}, #{license.display_name}, should not be deprecated.")
    end
end

  def test_current_names_and_ids_ccnc25
    names_and_ids = License.current_names_and_ids(licenses(:ccnc25))
    assert_equal(4, names_and_ids.length)
  end
end
