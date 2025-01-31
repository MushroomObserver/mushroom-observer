require("test_helper")
require("api2_extensions")

class API2::LocationDescriptionsTest < UnitTestCase
  include API2Extensions

  def test_basic_location_description_get
    do_basic_get_test(LocationDescription, public: true)
  end
end
