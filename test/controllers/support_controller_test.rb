# encoding: utf-8
require "test_helper"

class SupportControllerTest < FunctionalTestCase
  def test_gets
    [:donors, :confirm, :thanks,
     :letter, :wrapup_2011, :wrapup_2012].each do |template|
      assert_template_with_dump(template)
      get_with_dump(template)
      assert_template(template)
    end
  end

  def assert_template_with_dump(template)
    get_with_dump(template)
    assert_template(template)
  end

  def test_donate
    login("rolf")
    assert_template_with_dump(:donate)
    assert_select("form input[value=\"#{users(:rolf).name}\"]")
  end

  def test_confirm_post
    confirm_post(25, 0)
  end

  def confirm_post(amount, other_amount)
    donations = Donation.count
    anon = false
    final_amount = amount == "other" ? other_amount : amount
    params = donation_params(amount, rolf, anon)
    params[:donation][:other_amount] = other_amount
    post(:confirm, params)
    assert_template(:confirm)
    assert_donations(donations + 1, final_amount, rolf, anon, false)
  end

  def assert_donations(count, amount, user, anon, reviewed)
    donation = Donation.all.order("created_at DESC")[0]
    assert_equal([count, amount,
                  donation.user && user, user.name, user.email,
                  anon, reviewed],
                 [Donation.count, donation.amount,
                  donation.user, donation.who, donation.email,
                  donation.anonymous, donation.reviewed])
  end

  def donation_params(amount, user, anon)
    {
      donation: {
        amount: amount,
        who: user.name,
        email: user.email,
        anonymous: anon
      }
    }
  end

  def test_confirm_other_amount_post
    confirm_post("other", 30)
  end

  def test_create_donation
    get(:create_donation)
    assert_response(:redirect)
    make_admin
    assert_template_with_dump(:create_donation)
  end

  def test_create_donation_post
    create_donation_post(false)
  end

  def create_donation_post(anon)
    make_admin
    amount = 100.00
    donations = Donation.count
    params = donation_params(amount, rolf, anon)
    post(:create_donation, params)
    assert_donations(donations + 1, amount, rolf, anon, true)
  end

  def test_create_donation_anon_post
    create_donation_post(true)
  end

  def test_review_donations
    get(:review_donations)
    assert_response(:redirect)
    make_admin
    assert_template_with_dump(:review_donations)
  end

  def test_review_donations_post
    make_admin
    unreviewed = donations(:unreviewed)
    assert_equal(false, unreviewed.reviewed)
    params = { reviewed: { unreviewed.id => true } }
    post(:review_donations, params)
    reloaded = Donation.find(unreviewed.id)
    assert(reloaded.reviewed)
  end
end
