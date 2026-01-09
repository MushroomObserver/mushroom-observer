# frozen_string_literal: true

require("test_helper")

class AdminIntegrationTest < CapybaraIntegrationTestCase
  def setup
    super
    backup_ip_files
  end

  def teardown
    restore_ip_files
    super
  end

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
      fill_in("admin_session_user", with: "something unlikely and bogus")
      click_commit
    end
    assert_flash_text("Play again?")

    within("#admin_switch_users_form") do
      fill_in("admin_session_user", with: "unverified")
      click_commit
    end
    assert_flash_text("This user is not verified yet!")

    within("#admin_switch_users_form") do
      fill_in("admin_session_user", with: "mary")
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

    assert_selector("#okay_ips_manager_form")
    assert_selector("#blocked_ips_manager_form")

    # Test invalid IP validation (once is enough)
    within("#okay_ips_manager_form") do
      fill_in("okay_ips[add_okay]", with: "not.an.ip")
      click_commit
    end
    assert_flash_text("Invalid IP address")

    # Test both IP list types with shared logic
    [
      { type: :okay, form_key: "okay_ips", add_field: "add_okay" },
      { type: :blocked, form_key: "blocked_ips", add_field: "add_bad" }
    ].each do |config|
      assert_ip_manager_crud(config)
    end
  end

  private

  def assert_ip_manager_crud(config)
    type = config[:type]
    form_id = "#{type}_ips_manager_form"
    table_id = "#{type}_ips"
    field_name = "#{config[:form_key]}[#{config[:add_field]}]"
    ip1 = "3.4.5.6"
    ip2 = "3.14.15.9"

    # Clear list first
    click_on(id: "clear_#{type}_ips_list")

    # Verify empty
    within("##{table_id}") do
      refute_selector("td", text: ip1)
      refute_selector("td", text: ip2)
    end

    # Add two IPs
    within("##{form_id}") do
      fill_in(field_name, with: ip1)
      click_commit
      fill_in(field_name, with: ip2)
      click_commit
    end

    # Verify added, then remove one
    within("##{table_id}") do
      assert_selector("td", text: ip1)
      assert_selector("td", text: ip2)
      click_on(id: "remove_#{type}_ip_#{ip2}")
      refute_selector("td", text: ip2)
    end

    # Clear and verify empty
    click_on(id: "clear_#{type}_ips_list")
    within("##{table_id}") do
      refute_selector("td", text: ip1)
    end
  end

  def backup_ip_files
    @blocked_ips_backup = File.read(MO.blocked_ips_file) if
      File.exist?(MO.blocked_ips_file)
    @okay_ips_backup = File.read(MO.okay_ips_file) if
      File.exist?(MO.okay_ips_file)
  end

  def restore_ip_files
    if @blocked_ips_backup
      File.write(MO.blocked_ips_file, @blocked_ips_backup)
    elsif File.exist?(MO.blocked_ips_file)
      File.delete(MO.blocked_ips_file)
    end
    if @okay_ips_backup
      File.write(MO.okay_ips_file, @okay_ips_backup)
    elsif File.exist?(MO.okay_ips_file)
      File.delete(MO.okay_ips_file)
    end
  end
end
