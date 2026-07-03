# frozen_string_literal: true

require("application_system_test_case")

# Confirms the reviewer "export status" toggle actually updates in
# place via Turbo Stream in a real browser — a controller/component
# test can't tell us whether Turbo Drive picks up `data-turbo="true"`
# when it lands on the submitter <button> rather than the <form>
# (see `Components::Button::CRUDBase#button_html_options`).
class ExportStatusControlsSystemTest < ApplicationSystemTestCase
  def test_flip_export_status_updates_in_place
    name = names(:petigera)
    assert_true(name.ok_for_export) # fixture default

    login!(users(:rolf))
    visit(name_path(name.id))

    within("#ok_for_export_name_#{name.id}") do
      assert_selector("b", text: :review_ok_for_export.t.as_displayed)
      click_button(:review_no_export.t.as_displayed)
    end

    # Updated in place: bold state flips, flip button flips — without
    # a full page reload swapping in a fresh copy of the whole page.
    within("#ok_for_export_name_#{name.id}") do
      assert_selector("b", text: :review_no_export.t.as_displayed)
      assert_selector("button", text: :review_ok_for_export.t.as_displayed)
    end
    assert_selector("body.names__show")
    assert_false(name.reload.ok_for_export)

    # Flip it back via the now-visible button.
    within("#ok_for_export_name_#{name.id}") do
      click_button(:review_ok_for_export.t.as_displayed)
    end
    within("#ok_for_export_name_#{name.id}") do
      assert_selector("b", text: :review_ok_for_export.t.as_displayed)
    end
    assert_true(name.reload.ok_for_export)
  end

  def test_flip_diagnostic_status_updates_in_place
    image = images(:in_situ_image)
    image.update(diagnostic: true)

    login!(users(:rolf))
    # `image_path` is shadowed in system tests by
    # ActionDispatch::SystemTesting::TestHelpers::ScreenshotHelper's
    # zero-arg `image_path` (used for screenshot file paths) — must
    # go through url_helpers explicitly here.
    visit(Rails.application.routes.url_helpers.image_path(image.id))

    within("#diagnostic_image_#{image.id}") do
      assert_selector("b", text: :review_diagnostic.t.as_displayed)
      click_button(:review_non_diagnostic.t.as_displayed)
    end

    # Updated in place: bold state flips, flip button flips — without
    # a full page reload swapping in a fresh copy of the whole page.
    # The neighboring ok_for_export toggle is untouched by this flip.
    within("#diagnostic_image_#{image.id}") do
      assert_selector("b", text: :review_non_diagnostic.t.as_displayed)
      assert_selector("button", text: :review_diagnostic.t.as_displayed)
    end
    assert_selector("body.images__show")
    assert_false(image.reload.diagnostic)

    # Flip it back via the now-visible button.
    within("#diagnostic_image_#{image.id}") do
      click_button(:review_diagnostic.t.as_displayed)
    end
    within("#diagnostic_image_#{image.id}") do
      assert_selector("b", text: :review_diagnostic.t.as_displayed)
    end
    assert_true(image.reload.diagnostic)
  end
end
