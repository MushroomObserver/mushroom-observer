require File.dirname(__FILE__) + '/../boot'

class SupportControllerTest < FunctionalTestCase
  # Replace this with your real tests.
  def test_donors
    get_with_dump(:donors)
    assert_response('donors')
  end

  def test_donate
    get_with_dump(:donate)
    assert_response('donate')
  end

  def test_create_donation
    get(:create_donation)
    assert_response(:redirect)
    
    make_admin
    get_with_dump(:create_donation)
    assert_response('create_donation')
  end

  def test_thanks
    get_with_dump(:thanks)
    assert_response('thanks')
  end

  def test_letter
    get_with_dump(:letter)
    assert_response('letter')
  end
end
