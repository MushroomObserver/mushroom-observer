# frozen_string_literal: true

require("test_helper")

class AdminIntegrationTest < CapybaraIntegrationTestCase
  def test_turn_admin_mode_on_and_off
    refute_selector(id: "nav_admin_on_link")

    put_user_in_admin_mode(rolf)
    assert_selector(id: "nav_admin_off_link")

    click_on(id: "nav_admin_off_link")
    assert_selector(id: "nav_mobile_admin_link")
  end

  # This test is not much more than a stub.
  # Should test somebody making a donation, admin reviews.
  def test_review_donations
    visit("/admin/donations/edit")
    assert_flash_text(:permission_denied.t)

    put_user_in_admin_mode(rolf)

    visit("/admin/review_donations")
    assert_selector("body.donations__edit")

    within("#admin_review_donations_form") do
      click_commit
    end

    assert_selector("#admin_review_donations_form")
  end

  def test_switch_users
    refute_selector(id: "nav_admin_switch_users_link")

    put_user_in_admin_mode(rolf)
    click_on(id: "nav_admin_switch_users_link")

    within("#admin_switch_users_form") do
      fill_in("admin_session_id", with: "something unlikely and bogus")
      click_commit
    end
    assert_flash_text("Play again?")

    within("#admin_switch_users_form") do
      fill_in("admin_session_id", with: "unverified")
      click_commit
    end
    assert_flash_text("This user is not verified yet!")

    within("#admin_switch_users_form") do
      fill_in("admin_session_id", with: "mary")
      click_commit
    end
    assert_equal(mary.id, User.current_id)
    assert_selector("#admin_banner",
                    text: /DANGER: You are currently logged in as mary/)

    click_on(id: "user_nav_logout_link")
    assert_equal(rolf.id, User.current_id)
    assert_selector("#admin_banner",
                    text: /DANGER: You are in administrator mode/)
  end

  # Deactivated for now. Somehow this test strips all language tags
  # (the controller action does not, however).
  #
  # def test_edit_banner
  #   refute_selector(id: "nav_admin_edit_banner_link")

  #   put_user_in_admin_mode(rolf)
  #   click_on(id: "nav_admin_edit_banner_link")

  #   within("#admin_banner_form") do
  #     fill_in("val", with: "An **important** new banner")
  #     # first(:button, type: "submit", name: "commit").click
  #     click_commit
  #   end

  #   within("#message_banner") do
  #     assert_match(%r{An <b>important</b> new banner}, page.html)
  #   end
  # end

  def test_blocked_ips
    refute_selector(id: "nav_admin_blocked_ips_link")

    put_user_in_admin_mode(rolf)
    click_on(id: "nav_admin_blocked_ips_link")

    assert_selector("#admin_okay_ips_form")
    assert_selector("#admin_blocked_ips_form")

    click_on(id: "clear_okay_ips_list")

    # Be sure these are not already in the table
    within("#okay_ips") do
      refute_selector("td", text: "3.4.5.6")
      refute_selector("td", text: "3.14.15.9")
    end

    within("#admin_okay_ips_form") do
      fill_in("add_okay", with: "not.an.ip")
      click_commit
    end
    assert_flash_text("Invalid IP address")

    within("#admin_okay_ips_form") do
      fill_in("add_okay", with: "3.4.5.6")
      click_commit
      fill_in("add_okay", with: "3.14.15.9")
      click_commit
    end

    within("#okay_ips") do
      assert_selector("td", text: "3.4.5.6")
      assert_selector("td", text: "3.14.15.9")
      click_on(id: "remove_okay_ip_3.14.15.9")
      refute_selector("td", text: "3.14.15.9")
    end

    click_on(id: "clear_okay_ips_list")

    within("#okay_ips") do
      refute_selector("td", text: "3.4.5.6")
      refute_selector("td", text: "3.14.15.9")
    end

    click_on(id: "clear_blocked_ips_list")

    within("#admin_blocked_ips_form") do
      fill_in("add_bad", with: "3.4.5.6")
      click_commit
      fill_in("add_bad", with: "3.14.15.9")
      click_commit
    end

    within("#blocked_ips") do
      assert_selector("td", text: "3.4.5.6")
      assert_selector("td", text: "3.14.15.9")
      click_on(id: "remove_blocked_ip_3.14.15.9")
      refute_selector("td", text: "3.14.15.9")
    end

    click_on(id: "clear_blocked_ips_list")

    within("#blocked_ips") do
      refute_selector("td", text: "3.4.5.6")
      refute_selector("td", text: "1.2.3.4")
    end

    within("#admin_blocked_ips_form") do
      fill_in("add_bad", with: "1.2.3.4")
      click_commit
    end

    within("#blocked_ips") do
      assert_selector("td", text: "1.2.3.4")
    end
  end
end
