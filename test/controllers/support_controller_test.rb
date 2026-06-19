# frozen_string_literal: true

require("test_helper")

class SupportControllerTest < FunctionalTestCase
  # NOTE: zeitwerk does not autoload the /tests directory
  require_relative("donations_controller_test_helpers")
  include ::DonationsControllerTestHelpers

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
      assert_select("body.support__#{template}")
    end
  end

  def test_donate
    login("rolf")
    get(:donate)
    assert_select("body.support__donate")
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
    assert_select("body.support__confirm")
    assert_donations(donations + 1, final_amount, false, params[:donation])
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

  # Anonymous donation — covers the `donate_anonymous` branch in
  # `Views::Controllers::Support::Confirm#render_who_or_anonymous`.
  def test_confirm_anonymous_donation
    params = donation_params(25, rolf, true)
    params[:donation][:other_amount] = 0
    post(:confirm, params: params)
    assert_select("body.support__confirm")
  end

  # Recurring donation — covers the recurring-only PayPal hidden
  # fields (`cmd=_xclick-subscriptions`, `a3`, `p3`, `t3`, `src`,
  # `no_note`).
  def test_confirm_recurring_donation
    params = donation_params(50, rolf, false, true)
    params[:donation][:other_amount] = 0
    post(:confirm, params: params)
    assert_select("body.support__confirm")
    assert_select("input[name='cmd'][value='_xclick-subscriptions']")
    assert_select("input[name='a3']")
  end
end
