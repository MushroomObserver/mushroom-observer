# encoding: utf-8
require 'test_helper'

class PivotalControllerTest < FunctionalTestCase
  def test_donors
    if PIVOTAL_USERNAME != 'username'
      get_with_dump(:index)
      assert_response('index')
    end
  end
end
