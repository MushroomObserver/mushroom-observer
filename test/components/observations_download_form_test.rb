# frozen_string_literal: true

require "test_helper"

class ObservationsDownloadFormTest < ComponentTestCase
  def test_form_structure
    html = render_form

    assert_html(html, "form#observations_download_form")
    assert_html(html,
                "form[action*='observations/downloads']")

    # Format radio buttons
    assert_html(html,
                "input[type='radio'][name='download[format]']" \
                "[value='raw']")
    assert_html(html,
                "input[type='radio'][name='download[format]']" \
                "[value='adolf']")
    assert_html(html,
                "input[type='radio'][name='download[format]']" \
                "[value='dwca']")
    assert_html(html,
                "input[type='radio'][name='download[format]']" \
                "[value='symbiota']")
    assert_html(html,
                "input[type='radio'][name='download[format]']" \
                "[value='fundis']")

    # Encoding radio buttons
    assert_html(html,
                "input[type='radio'][name='download[encoding]']" \
                "[value='ASCII']")
    assert_html(html,
                "input[type='radio'][name='download[encoding]']" \
                "[value='UTF-8']")

    # Submit buttons
    assert_html(html, "input[type='submit'][value='Download']")
    assert_html(html, "input[type='submit'][value='Cancel']")
    assert_html(
      html,
      "input[type='submit']" \
      "[value='#{:download_observations_print_labels.l}']"
    )
  end

  def test_no_admin_options_for_regular_user
    html = render_form

    assert_no_html(html,
                   "input[type='radio'][value='mycoportal']")
    assert_no_html(html,
                   "input[type='radio']" \
                   "[value='mycoportal_image_list']")
  end

  def test_admin_options_visible_in_admin_mode
    stub_admin_mode!
    html = render_form

    assert_html(html,
                "input[type='radio'][value='mycoportal']")
    assert_html(html,
                "input[type='radio']" \
                "[value='mycoportal_image_list']")
  end

  def test_checked_format_and_encoding
    html = render_form(format: "adolf", encoding: "ASCII")

    assert_html(html,
                "input[type='radio'][value='adolf'][checked]")
    assert_html(html,
                "input[type='radio'][value='ASCII'][checked]")
  end

  private

  def render_form(format: "raw", encoding: "UTF-8")
    render(Components::ObservationsDownloadForm.new(
             query_param: "abc123",
             format: format,
             encoding: encoding
           ))
  end
end
