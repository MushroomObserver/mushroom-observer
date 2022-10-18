# frozen_string_literal: true

require("test_helper")

class CapybaraAdminTest < CapybaraIntegrationTestCase
  def test_csrf_bug_in_review_donations_page
    put_user_in_admin_mode(rolf)

    visit("/support/review_donations")

    # There are two of these submit buttons too
    first(:button, type: "submit", name: "commit").click
    # If it fails it renders a simple text message.
    assert_selector("form")
  end

  def test_switch_users
    put_user_in_admin_mode(rolf)

    click_on(id: "nav_admin_switch_users_link")
    within("#admin_switch_users_form") do
      fill_in("id", with: "mary")
      first(:button, type: "submit", name: "commit").click
    end

    assert_equal(mary.id, User.current_id)
    assert_match(/DANGER: You are currently logged in as mary/, page.html)

    click_on(id: "user_nav_logout_link")
    assert_equal(rolf.id, User.current_id)
    assert_match(/DANGER: You are in administrator mode/, page.html)
  end

  def test_change_banner
    put_user_in_admin_mode(rolf)
    visit("/admin/change_banner")

    within("#admin_change_banner_form") do
      fill_in("val", with: "An **important** new banner")
      first(:button, type: "submit", name: "commit").click
    end

    within("#message_banner") do
      assert_match(%r{An <b>important</b> new banner}, page.html)
    end
  end

  def test_add_user_to_group; end
  def test_blocked_ips; end

  # def make_rolf_in_admin_mode
  #   rolf.admin = true
  #   rolf.save!
  #   login(rolf.login)
  #   assert_equal(rolf.id, User.current_id)

  #   click_on(id: "user_nav_admin_link")
  #   assert_match(/DANGER: You are in administrator mode/, page.html)
  # end
end
