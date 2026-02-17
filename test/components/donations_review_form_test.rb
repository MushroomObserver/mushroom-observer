# frozen_string_literal: true

require "test_helper"

class DonationsReviewFormTest < ComponentTestCase
  def setup
    super
    @donations = Donation.order(created_at: :desc).limit(3)
  end

  def test_renders_form_structure
    html = render_form

    # Form tag with correct attributes
    assert_html(html, "form[action='/admin/donations']")
    assert_html(html, "form[id='admin_review_donations_form']")
    assert_html(html, "form[style='display: contents']")

    # CSRF token and PATCH method (from Superform)
    assert_html(html, "input[name='authenticity_token']")
    assert_html(html, "input[name='_method'][value='patch']")
  end

  def test_renders_submit_buttons
    html = render_form

    assert_html(
      html,
      "input[type='submit']" \
      "[value='#{:review_donations_update.l}']",
      minimum: 2
    )
  end

  def test_renders_checkboxes_for_each_donation
    html = render_form

    @donations.each do |donation|
      # Hidden input + checkbox pair (Superform checkbox)
      assert_html(
        html,
        "input[name='reviewed[#{donation.id}]']" \
        "[type='hidden'][value='0']"
      )
      assert_html(
        html,
        "input[name='reviewed[#{donation.id}]']" \
        "[type='checkbox']"
      )
    end
  end

  def test_renders_table_columns
    html = render_form

    assert_html(html, "table.table")
    @donations.each do |d|
      assert_includes(html, d.id.to_s)
      assert_includes(html, d.amount.to_s)
    end
  end

  private

  def render_form
    render(Components::DonationsReviewForm.new(
             FormObject::ReviewDonations.new,
             donations: @donations
           ))
  end
end
