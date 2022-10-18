# frozen_string_literal: true

require("test_helper")

class CapybaraAdminTest < CapybaraIntegrationTestCase
  def test_review_donations
    visit("/support/review_donations")
    assert_flash_text(:review_donations_not_allowed.t)

    put_user_in_admin_mode(rolf)

    visit("/support/review_donations")

    # There are two of these submit buttons too
    click_commit
    # If it fails it renders a simple text message.
    assert_selector("form")
  end

  def test_switch_users
    refute_selector(id: "nav_admin_switch_users_link")

    put_user_in_admin_mode(rolf)
    click_on(id: "nav_admin_switch_users_link")

    within("#admin_switch_users_form") do
      fill_in("id", with: "bogus")
      click_commit
    end
    assert_flash_text("Couldn't find \"bogus\".  Play again?")

    within("#admin_switch_users_form") do
      fill_in("id", with: "mary")
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

  def test_change_banner
    refute_selector(id: "nav_admin_change_banner_link")

    put_user_in_admin_mode(rolf)
    click_on(id: "nav_admin_change_banner_link")

    within("#admin_change_banner_form") do
      fill_in("val", with: "An **important** new banner")
      click_commit
    end

    within("#message_banner") do
      assert_match(%r{An <b>important</b> new banner}, page.html)
    end
  end

  def test_add_user_to_group
    refute_selector(id: "nav_admin_add_user_to_group_link")

    put_user_in_admin_mode(rolf)
    click_on(id: "nav_admin_add_user_to_group_link")

    within("#admin_add_user_to_group_form") do
      fill_in("user_name", with: "bogus")
      fill_in("group_name", with: "all users")
      click_commit
    end
    assert_flash_text("#{:add_user_to_group_no_user.t(user: "bogus")}")

    within("#admin_add_user_to_group_form") do
      fill_in("user_name", with: "rolf")
      fill_in("group_name", with: "bogus")
      click_commit
    end
    assert_flash_text("#{:add_user_to_group_no_group.t(group: "bogus")}")

    within("#admin_add_user_to_group_form") do
      # rolf is already a member of all users. no go
      fill_in("user_name", with: "rolf")
      fill_in("group_name", with: "all users")
      click_commit
    end
    assert_flash_text("#{:add_user_to_group_already. \
        t(user: "rolf", group: "all users")}")

    within("#admin_add_user_to_group_form") do
      # rolf is not a member of Bolete Project, so can be added
      fill_in("user_name", with: "rolf")
      fill_in("group_name", with: "Bolete Project")
      click_commit
    end
    assert_flash_success
  end

  def test_blocked_ips
    refute_selector(id: "nav_admin_blocked_ips_link")

    put_user_in_admin_mode(rolf)
    click_on(id: "nav_admin_blocked_ips_link")

    assert_selector("#admin_okay_ips_form")
    assert_selector("#admin_blocked_ips_form")

    within("#okay_ips") do
      assert_selector("td", text: "3.14.15.9")
    end

    within("#blocked_ips") do
      assert_selector("td", text: "1.2.3.4")
      assert_selector("td", text: "3.14.15.9")
      assert_selector("td", text: "12.34.56.78")
      assert_selector("td", text: "97.53.10.86")
    end

    within("#admin_okay_ips_form") do
      fill_in("add_okay", with: "not.an.ip")
      click_commit
    end
    assert_flash_text("Invalid IP address")

    within("#admin_okay_ips_form") do
      fill_in("add_okay", with: "3.4.5.6")
      click_commit
    end

    within("#okay_ips") do
      assert_selector("td", text: "3.4.5.6")
    end

    within("#admin_blocked_ips_form") do
    end
  end
end
