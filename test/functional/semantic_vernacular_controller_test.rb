require File.expand_path(File.dirname(__FILE__) + '/../boot')

class SemanticVernacularControllerTest < FunctionalTestCase
  def test_index
    get_with_dump(:index)
    assert_response('index')
  end
end
