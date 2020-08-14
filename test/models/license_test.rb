# frozen_string_literal: true

require("test_helper")

class LicenseTest < UnitTestCase
  def test_current_names_and_ids
    names_and_ids = License.current_names_and_ids
    assert_equal(3, names_and_ids.length)
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
    assert_equal(4, names_and_ids.length)
  end
end
