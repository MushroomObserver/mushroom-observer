# frozen_string_literal: true

require("test_helper")
require("set")

module Names
  class VersionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_show_past_name
      login
      get(:show, params: { id: names(:coprinus_comatus).id })
      assert_template("show")
    end

    def test_show_past_name_with_misspelling
      login
      get(:show, params: { id: names(:petigera).id })
      assert_template("show")
    end
  end
end
