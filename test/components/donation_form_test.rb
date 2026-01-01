# frozen_string_literal: true

require "test_helper"

class DonationFormTest < ComponentTestCase
  def setup
    super
    @donation = Donation.new
    @html = render_form
  end

  def test_renders_form_with_amount_field
    assert_html(@html, "body", text: :confirm_amount.l)
    assert_html(@html, "input[name='donation[amount]']")
    assert_html(@html, "input[size='7']")
  end

  def test_renders_form_with_who_field
    assert_html(@html, "body", text: :WHO.l)
    assert_html(@html, "input[name='donation[who]']")
    assert_html(@html, "input[size='50']")
  end

  def test_renders_form_with_anonymous_checkbox
    assert_html(@html, "body", text: :donate_anonymous.l)
    assert_html(@html, "input[name='donation[anonymous]']")
    assert_html(@html, "input[type='checkbox']")
  end

  def test_renders_form_with_email_field
    assert_html(@html, "body", text: :EMAIL.l)
    assert_html(@html, "input[name='donation[email]']")
  end

  def test_renders_submit_button
    assert_html(@html,
                "input[type='submit'][value='#{:create_donation_add.l}']")
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
