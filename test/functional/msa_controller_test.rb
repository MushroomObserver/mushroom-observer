require File.expand_path(File.dirname(__FILE__) + '/../boot')

class MsaControllerTest < FunctionalTestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end
  
  def test_foray_registration
    get_with_dump(:foray_registration)
    assert_response('foray_registration')
  end
end
