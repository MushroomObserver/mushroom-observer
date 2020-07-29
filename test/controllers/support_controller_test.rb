# frozen_string_literal: true

require "test_helper"

# Donations to MO; information about donations
class SupportControllerTest < FunctionalTestCase
  def test_gets
    [
      :donors,
      :confirm,
      :thanks,
      :governance,
      :letter,
      :wrapup_2011,
      :wrapup_2012
    ].each do |template|
      assert_template_with_dump(template)
      get(template)
      assert_template(template)
    end
  end

  def assert_template_with_dump(template)
    get(template)
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
    recurring = false
    final_amount = amount == "other" ? other_amount : amount
    params = donation_params(amount, rolf, anon, recurring)
    params[:donation][:other_amount] = other_amount
    post(:confirm, params)
    assert_template(:confirm)
    assert_donations(donations + 1, final_amount, false, params[:donation])
  end

  def assert_donations(count, final_amount, reviewed, params)
    donation = Donation.all.order("created_at DESC")[0]
    assert_equal([count, final_amount, reviewed],
                 [Donation.count, donation.amount, donation.reviewed])
    assert_donation_params(params, donation)
  end

  def assert_donation_params(params, donation)
    assert_equal([params[:who], params[:email],
                  params[:anonymous], params[:recurring]],
                 [donation.who, donation.email,
                  donation.anonymous, donation.recurring])
  end

  def donation_params(amount, user, anon, recurring = false)
    {
      donation: {
        amount: amount,
        who: user.name,
        email: user.email,
        anonymous: anon,
        recurring: recurring,
        reviewed: false
      }
    }
  end

  def test_confirm_other_amount_post
    confirm_post("other", 30)
  end

  def test_confirm_bad_other_amount
    amount = 0
    params = donation_params(amount, rolf, false)
    params[:donation][:other_amount] = amount
    post(:confirm, params)
    assert_flash_text(:confirm_positive_number_error.t)
  end

  def test_create_donation
    get(:create_donation)
    assert_response(:redirect)
    make_admin
    assert_template_with_dump(:create_donation)
  end

  def test_create_donation_post
    create_donation_post(false, false)
  end

  def create_donation_post(anon, recurring)
    make_admin
    amount = 100.00
    donations = Donation.count
    params = donation_params(amount, rolf, anon, recurring)
    post(:create_donation, params)
    assert_donations(donations + 1, amount, true, params[:donation])
  end

  def test_create_donation_anon_recurring_post
    create_donation_post(true, true)
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
