require File.expand_path(File.dirname(__FILE__) + '/../boot')

class SemanticVernacularAppControllerTest < FunctionalTestCase
  def test_index
    get_with_dump(:index_vernaculars)
    assert_response('index_vernaculars')
  end
end
