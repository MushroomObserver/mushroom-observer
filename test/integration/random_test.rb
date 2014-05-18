# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../boot')

# class NameControllerTest < FunctionalTestCase
#   def test_min; assert(true); end
# end

class RandomTest < IntegrationTestCase # ActionController::IntegrationTest
  fixtures :names
  
  def test_pivotal
    get('/')
    click(:label => 'Feature Tracker')
    assert_template('pivotal/index')
  end

  # Test "/controller/action/type/id" route used by AJAX controller.
  def test_ajax_router
    get('/ajax/auto_complete/name/Agaricus')
    assert_response(:success)
    lines = response.body.split("\n")
    assert_equal('A', lines.first)
    assert(lines.include?('Agaricus'))
    assert(lines.include?('Agaricus campestris'))
  end
end
