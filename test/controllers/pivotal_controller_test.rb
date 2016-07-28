# encoding: utf-8
require "test_helper"

class PivotalControllerTest < FunctionalTestCase
  def test_index
    return unless MO.pivotal_enabled

    get_with_dump(:index)
    assert_response("index")
  end
end
