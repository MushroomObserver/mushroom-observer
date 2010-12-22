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

  def confirm_post(amount, other_amount)
    user = @rolf
    donations = Donation.count
    anon = false
    final_amount = (amount == 'other') ? other_amount : amount
    params = {
      :donation => {
        :amount => amount,
        :other_amount => other_amount,
        :who => user.name,
        :email => user.email,
        :anonymous => anon,
      }
    }
    post(:confirm, params)
    assert_response('confirm')
    assert_equal(donations + 1, Donation.count)
    donation = Donation.find(:all, :order => "created_at DESC")[0]
    assert_equal(final_amount, donation.amount)
    assert_equal(user.name, donation.who)
    assert_equal(user.email, donation.email)
    assert_equal(anon, donation.anonymous)
    assert_equal(false, donation.reviewed)
  end

  def test_confirm_post
    confirm_post(25, 0)
  end
  
  def test_confirm_other_amount_post
    confirm_post('other', 30)
  end
  
  def test_create_donation
    get(:create_donation)
    assert_response(:redirect)
    
    make_admin
    get_with_dump(:create_donation)
    assert_response('create_donation')
  end

  def create_donation_post(anon)
    make_admin
    user = @rolf
    amount = 100.00
    donations = Donation.count
    params = {
      :donation => {
        :amount => amount,
        :who => user.name,
        :email => user.email,
        :anonymous => anon,
      }
    }
    post(:create_donation, params)
    assert_equal(donations + 1, Donation.count)
    donation = Donation.find(:all, :order => "created_at DESC")[0]
    assert_equal(amount, donation.amount)
    assert_equal(user.name, donation.who)
    assert_equal(user.email, donation.email)
    assert_equal(anon, donation.anonymous)
    assert_equal(true, donation.reviewed)
  end

  def test_create_donation_post
    create_donation_post(false)
  end

  def test_create_donation_anon_post
    create_donation_post(true)
  end
  
  def test_review_donations
    get(:review_donations)
    assert_response(:redirect)
    
    make_admin
    get_with_dump(:review_donations)
    assert_response('review_donations')
  end

  def test_review_donations_post
    make_admin
    unreviewed = donations(:unreviewed)
    assert_equal(false, unreviewed.reviewed)
    params = {
      :reviewed => {
        unreviewed.id => true,
      }
    }
    post(:review_donations, params)
    reloaded = Donation.find(unreviewed.id)
    assert(reloaded.reviewed)
  end

  def test_thanks
    user = @rolf
    amount = 95.00
    anon = false
    donations = Donation.count
    params = { # This should really be done through cookies, but I can't figure that out.
      :donation_amount => amount,
      :who => user.name,
      :email => user.email,
      :anon => anon,
    }
    login(@rolf.login)
    get_with_dump(:thanks, params)
    assert_response('thanks')
    assert_equal(donations + 1, Donation.count)
    donation = Donation.find(:all, :order => "created_at DESC")[0]
    assert_equal(amount, donation.amount)
    assert_equal(user.name, donation.who)
    assert_equal(user.email, donation.email)
    assert_equal(anon, donation.anonymous)
    assert_equal(false, donation.reviewed)
    assert_equal(@rolf, donation.user)
  end

  def test_letter
    get_with_dump(:letter)
    assert_response('letter')
  end
end
