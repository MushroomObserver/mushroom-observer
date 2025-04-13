# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::NameDescriptionsTest < UnitTestCase
  include API2Extensions

  def test_basic_name_description_get
    do_basic_get_test(NameDescription, public: true)
  end

  def params_get(**)
    { method: :get, action: :name_description }.merge(**)
  end

  def test_name_description_get_names
    public = [name_descriptions(:peltigera_alt_desc),
              name_descriptions(:peltigera_desc),
              name_descriptions(:peltigera_source_desc)]
    assert_api_pass(params_get(name: "Peltigera", include_synonyms: "yes"))
    assert_api_results(public)
  end
end
