# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class LicenseTest < UnitTestCase

  def test_current_names_and_ids
    names_and_ids = License.current_names_and_ids()
    assert_equal(2, names_and_ids.length)
    for (name, id) in names_and_ids
      license = License.find(id)
      assert_equal(false, license.deprecated)
    end
  end

  def test_current_names_and_ids_ccnc25
    names_and_ids = License.current_names_and_ids(licenses(:ccnc25))
    assert_equal(3, names_and_ids.length)
  end
end
