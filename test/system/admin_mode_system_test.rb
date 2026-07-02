# frozen_string_literal: true

require("application_system_test_case")

class AdminModeSystemTest < ApplicationSystemTestCase
  def setup
    super
    rolf.admin = true
    rolf.save!
    login!(rolf)
  end

  def test_admin_mode_toggle_dom_and_css
    visit("/info/how_to_help")
    assert_admin_toggle_works
  end

  # iNat import pages use a Turbo Frame — regression reported by Nathan
  # where the admin mode button failed to apply on those pages.
  def test_admin_mode_toggle_from_inat_import_page
    visit(inat_import_path(inat_imports(:rolf_inat_import)))
    assert_admin_toggle_works
  end

  private

  def admin_stylesheet_present?
    page.evaluate_script(
      "Array.from(document.querySelectorAll('link[rel=stylesheet]'))" \
      ".some(l => l.href.includes('Admin'))"
    )
  end
end
