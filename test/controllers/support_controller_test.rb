# frozen_string_literal: true

require("test_helper")

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
      get(template)
      assert_template(template)
    end
  end

  def test_donate
    login("rolf")
    get(:donate)
    assert_template(:donate)
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
    post(:confirm, params: params)
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
    post(:confirm, params: params)
    assert_flash_text(:confirm_positive_number_error.t)
  end
end
