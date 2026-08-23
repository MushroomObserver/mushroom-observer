# frozen_string_literal: true

require("test_helper")

# Components::FieldSlipScanState -- the scan-state buttons for a photo
# with an existing field slip read.
class FieldSlipScanStateTest < ComponentTestCase
  def setup
    super
    @image = images(:in_situ_image)
  end

  def test_renders_nothing_without_a_read
    html = render_state(nil)

    assert_equal("", html.strip)
  end

  def test_complete_read_links_to_the_review_form_as_a_button
    html = render_state(complete_read)

    assert_html(html, "a.btn.btn-default[href='#{review_path}']",
                text: :field_slip_scan_review.l)
    assert_no_html(html, "form")
  end

  def test_pending_read_links_to_the_status_page_as_a_button
    html = render_state(FieldSlipExtract.start!(image: @image, user: rolf))

    assert_html(html, "a.btn[href='#{review_path}']",
                text: :field_slip_scan_reading.l)
    assert_no_html(html, "form")
  end

  def test_failed_read_offers_view_and_retry_buttons
    html = render_state(failed_read)

    assert_html(html, "a.btn[href='#{review_path}']",
                text: :field_slip_scan_failed.l)
    assert_html(html, "form[action='#{read_path}'] button.btn.ml-2",
                text: :field_slip_scan_retry.l)
  end

  # Pages with their own Read Field Slip button (which re-reads) skip
  # the Retry button.
  def test_failed_read_without_retry
    html = render_state(failed_read, offer_retry: false)

    assert_html(html, "a.btn[href='#{review_path}']")
    assert_no_html(html, "form")
  end

  private

  def render_state(extract, offer_retry: true)
    render(Components::FieldSlipScanState.new(
             image: @image, extract: extract, offer_retry: offer_retry
           ))
  end

  def review_path
    routes.edit_image_field_slip_extract_path(@image.id)
  end

  def read_path
    routes.image_field_slip_extract_path(@image.id)
  end

  def failed_read
    FieldSlipExtract.fail!(image: @image, user: rolf, error: "x")
  end

  def complete_read
    FieldSlipExtract.record(
      image: @image, user: rolf, prompt_version: "1",
      result: FieldSlip::Extractor::Result.new(
        provider: "g", model: "m", raw: {}, template: "mo",
        fields: { "Collector" => "A" }, confidence: {}
      )
    )
  end
end
