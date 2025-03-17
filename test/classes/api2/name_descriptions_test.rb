# frozen_string_literal: true

require "test_helper"
require "api2_extensions"

class API2::NameDescriptionsTest < UnitTestCase
  include API2Extensions

  def test_basic_name_description_get
    do_basic_get_test(NameDescription, public: true)
  end
end
