# frozen_string_literal: true

require("application_system_test_case")

class AdminModeSystemTest < ApplicationSystemTestCase
  def setup
    super
    rolf.admin = true
    rolf.save!
    login!(rolf)
  end

  def test_admin_mode_toggle_dom_and_css_from_info_page
    visit("/info/how_to_help")
    assert_admin_toggle_works
  end

  # The iNat import show page subscribes to a Turbo Stream — regression
  # reported by Nathan where the admin mode button failed to apply there.
  def test_admin_mode_toggle_from_inat_import_page
    visit(inat_import_path(inat_imports(:rolf_inat_import)))
    assert_admin_toggle_works
  end

  # Observation show also holds an open Turbo Stream subscription
  # (comments, via Views::Controllers::Comments::CommentsForObject's
  # `turbo_stream_from(@object, :comments)`) — same class of page as
  # the iNat import show test above, added to scope how far #4659's
  # finding reaches. Verified locally by temporarily removing
  # Tab::UserNav::AdminMode's `data: { turbo: false }` opt-out: unlike
  # the iNat import page (where the post-toggle redirect is never
  # followed — turbo:submit-end fires, then nothing), THIS page's
  # toggle still works fine without the opt-out. So the "redirect
  # never followed" failure isn't universal to any page with an open
  # Turbo Stream subscription — something more specific to the iNat
  # import page's subscription is involved. Passes today regardless,
  # since the opt-out is in place either way.
  def test_admin_mode_toggle_from_observation_show_page
    visit(observation_path(observations(:minimal_unknown_obs).id))
    assert_admin_toggle_works
  end

  private

  def assert_admin_toggle_works
    assert_no_selector("#admin_banner")
    assert_not(admin_stylesheet_present?,
               "Admin stylesheet should not be present in normal mode")

    click_on(id: "user_nav_toggle")
    click_on(id: "user_nav_admin_mode_link")

    assert_selector("#admin_banner",
                    text: "DANGER: You are in administrator mode")
    assert(admin_stylesheet_present?,
           "Admin stylesheet should be present after enabling admin mode")

    click_on(id: "user_nav_toggle")
    click_on(id: "user_nav_admin_mode_link")

    assert_no_selector("#admin_banner")
    assert_not(admin_stylesheet_present?,
               "Admin stylesheet should not be present after disabling " \
               "admin mode (Turbo head-append regression)")
  end

  def admin_stylesheet_present?
    page.evaluate_script(
      "Array.from(document.querySelectorAll('link[rel=stylesheet]'))" \
      ".some(l => l.href.includes('Admin'))"
    )
  end
end
