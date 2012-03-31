require File.expand_path(File.dirname(__FILE__) + '/../boot')

class ConferenceControllerTest < FunctionalTestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end
  
  def test_register
    get_with_dump(:register)
    assert_response('register')
  end
end
