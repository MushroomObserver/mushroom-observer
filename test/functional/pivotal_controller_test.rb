# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class PivotalControllerTest < FunctionalTestCase
  def test_donors
    if PIVOTAL_USERNAME != 'username'
      get_with_dump(:index)
      assert_response('index')
    end
  end
end
