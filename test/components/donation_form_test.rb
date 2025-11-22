# frozen_string_literal: true

require "test_helper"

class DonationFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @donation = Donation.new
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_amount_field
    assert_includes(@html, :confirm_amount.t)
    assert_html(@html, "input[name='donation[amount]']")
    assert_html(@html, "input[size='7']")
  end

  def test_renders_form_with_who_field
    assert_includes(@html, :WHO.t)
    assert_html(@html, "input[name='donation[who]']")
    assert_html(@html, "input[size='50']")
  end

  def test_renders_form_with_anonymous_checkbox
    assert_includes(@html, :donate_anonymous.t)
    assert_html(@html, "input[name='donation[anonymous]']")
    assert_html(@html, "input[type='checkbox']")
  end

  def test_renders_form_with_email_field
    assert_includes(@html, :EMAIL.t)
    assert_html(@html, "input[name='donation[email]']")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:create_donation_add.l}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form
    form = Components::DonationForm.new(
      @donation,
      action: "/test_action",
      id: "donation_form"
    )
    render(form)
  end
end
