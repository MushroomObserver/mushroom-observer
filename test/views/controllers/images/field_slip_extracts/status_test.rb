# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::FieldSlipExtracts
  class StatusTest < ComponentTestCase
    # A proxy, not an include: including url_helpers makes MiniTest
    # pick up route helpers named test_* as test methods.
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      super
      @user = users(:rolf)
      @obs = observations(:minimal_unknown_obs)
      @image = images(:in_situ_image)
      @obs.images << @image unless @obs.images.include?(@image)
    end

    def render_status(extract: nil)
      render(Status.new(image: @image, extract: extract, user: @user))
    end

    def test_pending_read_self_refreshes
      extract = FieldSlipExtract.start!(image: @image, user: @user)

      html = render_status(extract: extract)

      assert_html(html, "[data-controller='reload-poll']")
      assert_html(html, "#field_slip_extract_pending",
                  text: :field_slip_extract_pending.t.as_displayed[0, 40])
      # The view links image.observations.first -- the fixture image
      # hangs off several observations, so pin whichever IS first
      # rather than assuming an association order.
      linked = @image.reload.observations.first

      assert_html(
        html, "a[href='#{routes.permanent_observation_path(linked.id)}']"
      )
    end

    # No extract: the not-scanned-yet state offers the scan button and
    # does NOT poll -- nothing is running until it is pressed. This is
    # where the no-slip-detected flash lands, and how a zbar-missed
    # slip photo gets read at all.
    def test_unscanned_state_offers_the_scan_button
      html = render_status

      assert_html(html, "#field_slip_extract_none",
                  text: :field_slip_extract_none_yet.t.as_displayed[0, 40])
      assert_html(
        html,
        "form[action='#{routes.image_field_slip_extract_path(@image.id)}'] " \
        "button[type='submit']"
      )
      assert_no_html(html, "[data-controller='reload-poll']")
    end

    def test_failed_read_shows_the_error_and_a_retry_button
      extract = FieldSlipExtract.fail!(image: @image, user: @user,
                                       error: "429 quota exceeded")

      html = render_status(extract: extract)

      assert_html(html, ".alert-danger", text: "429 quota exceeded")
      assert_html(
        html,
        "form[action='#{routes.image_field_slip_extract_path(@image.id)}'] " \
        "button[type='submit']"
      )
      assert_no_html(html, "[data-controller='reload-poll']")
    end
  end
end
