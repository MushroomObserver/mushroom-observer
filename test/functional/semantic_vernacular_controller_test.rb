require File.expand_path(File.dirname(__FILE__) + '/../boot')

class SemanticVernacularControllerTest < FunctionalTestCase
  # Replace this with your real tests.
  def test_index
    get_with_dump(:index)
    assert_response('index')
  end
end
