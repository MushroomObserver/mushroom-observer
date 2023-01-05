# frozen_string_literal: true

require("test_helper")
require("set")

module Names
  class VersionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

  def test_show_past_name
    login
    get(:show_past_name, params: { id: names(:coprinus_comatus).id })
    assert_template(:show_past_name)
  end

  def test_show_past_name_with_misspelling
    login
    get(:show_past_name, params: { id: names(:petigera).id })
    assert_template(:show_past_name)
  end

  end
end
