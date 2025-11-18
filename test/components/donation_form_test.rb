# frozen_string_literal: true

require "test_helper"

class DonationFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @donation = Donation.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_amount_field
    form = render_form

    assert_includes(form, :confirm_amount.t)
    assert_includes(form, 'name="donation[amount]"')
    assert_includes(form, 'size="7"')
  end

  def test_renders_form_with_who_field
    form = render_form

    assert_includes(form, :WHO.t)
    assert_includes(form, 'name="donation[who]"')
    assert_includes(form, 'size="50"')
  end

  def test_renders_form_with_anonymous_checkbox
    form = render_form

    assert_includes(form, :donate_anonymous.t)
    assert_includes(form, 'name="donation[anonymous]"')
    assert_includes(form, 'type="checkbox"')
  end

  def test_renders_form_with_email_field
    form = render_form

    assert_includes(form, :EMAIL.t)
    assert_includes(form, 'name="donation[email]"')
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :create_donation_add.l)
    assert_includes(form, "center-block")
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
