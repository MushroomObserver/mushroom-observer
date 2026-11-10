# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Admin::Donations
  class ReviewToggleTest < ComponentTestCase
    def setup
      super
      @donation = Donation.first
    end

    def test_renders_self_submitting_form
      html = render_toggle

      assert_html(html, "form[id='donation_reviewed_#{@donation.id}']" \
                        "[action='/admin/donations']")
      assert_html(html, "form[data-controller='reviewed-toggle']")
      assert_html(html, "input[name='_method'][value='patch']")
    end

    def test_renders_checkbox_wired_to_submit_on_change
      html = render_toggle

      assert_html(
        html,
        "input[name='reviewed[#{@donation.id}]'][type='checkbox']" \
        "[data-reviewed-toggle-target='toggle']" \
        "[data-action='reviewed-toggle#submitForm']"
      )
    end

    def test_checked_reflects_donation_state
      @donation.update_column(:reviewed, true)
      assert_html(render_toggle, "input[type='checkbox'][checked]")

      @donation.update_column(:reviewed, false)
      assert_no_html(render_toggle, "input[type='checkbox'][checked]")
    end

    def test_label_shows_only_when_reviewed
      @donation.update_column(:reviewed, true)
      assert_html(render_toggle, "label", text: :reviewed.ti.as_displayed)

      @donation.update_column(:reviewed, false)
      assert_no_html(render_toggle, "label", text: :reviewed.ti.as_displayed)
    end

    private

    def render_toggle
      render(ReviewToggle.new(donation: @donation))
    end
  end
end
