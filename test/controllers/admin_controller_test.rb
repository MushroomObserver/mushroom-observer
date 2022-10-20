# frozen_string_literal: true

require("test_helper")

# Controller tests for info pages
class AdminControllerTest < FunctionalTestCase
  def test_change_banner
    use_test_locales do
      # Oops!  One of these tags actually exists now!
      TranslationString.where(tag: "app_banner_box").each(&:destroy)

      str1 = TranslationString.create!(
        language: languages(:english),
        tag: :app_banner_box,
        text: "old banner",
        user: User.admin
      )
      str1.update_localization

      str2 = TranslationString.create!(
        language: languages(:french),
        tag: :app_banner_box,
        text: "banner ancienne",
        user: User.admin
      )
      str2.update_localization

      get(:change_banner)
      assert_redirected_to(new_account_login_path)

      login("rolf")
      get(:change_banner)
      assert_flash_error
      assert_redirected_to("/")

      make_admin("rolf")
      get(:change_banner)
      assert_no_flash
      assert_response(:success)
      assert_textarea_value(:val, :app_banner_box.l)

      post(:change_banner, params: { val: "new banner" })
      assert_no_flash
      assert_redirected_to("/")
      assert_equal("new banner", :app_banner_box.l)

      strs = TranslationString.where(tag: :app_banner_box)
      strs.each do |str|
        assert_equal("new banner", str.text,
                     "Didn't change text of #{str.language.locale} correctly.")
      end
    end
  end

  ######## Test Admin Methods ##################################################

  def test_add_user_to_group
    login(:rolf)
    post(:add_user_to_group)
    assert_flash_error

    # Happy path
    make_admin
    post(:add_user_to_group,
         params: { user_name: users(:roy).login,
                   group_name: user_groups(:bolete_users).name })
    assert_flash_success
    assert(users(:roy).in_group?(user_groups(:bolete_users).name))

    # Unhappy paths
    post(:add_user_to_group,
         params: { user_name: users(:roy).login,
                   group_name: user_groups(:bolete_users).name })
    assert_flash_warning # Roy is already a member; we just added him above.

    post(:add_user_to_group,
         params: { user_name: "AbsoluteNonsenseVermslons",
                   group_name: user_groups(:bolete_users).name })
    assert_flash_error

    post(:add_user_to_group,
         params: { user_name: users(:roy).login,
                   group_name: "AbsoluteNonsenseVermslons" })
    assert_flash_error
  end

  def test_blocked_ips
    new_ip = "5.4.3.2"
    IpStats.remove_blocked_ips([new_ip])
    # make sure there is an API key logged to test that part of view
    api_key = api_keys(:rolfs_api_key)
    IpStats.log_stats({ ip: "3.14.15.9",
                        time: Time.zone.now,
                        controller: "api",
                        action: "observations",
                        api_key: api_key.key })
    assert_false(IpStats.blocked?(new_ip))

    login(:rolf)
    get(:blocked_ips)
    assert_response(:redirect)

    make_admin
    get(:blocked_ips)
    assert_response(:success)
    assert_includes(@response.body, api_key.key)

    get(:blocked_ips, params: { add_bad: "garbage" })
    assert_flash_error

    time = 1.minute.ago
    File.utime(time.to_time, time.to_time, MO.blocked_ips_file)
    get(:blocked_ips, params: { add_bad: new_ip })
    assert_no_flash
    assert(time < File.mtime(MO.blocked_ips_file))
    IpStats.reset!
    assert_true(IpStats.blocked?(new_ip))

    time = 1.minute.ago
    File.utime(time.to_time, time.to_time, MO.blocked_ips_file)
    get(:blocked_ips, params: { remove_bad: new_ip })
    assert_no_flash
    assert(time < File.mtime(MO.blocked_ips_file))
    IpStats.reset!
    assert_false(IpStats.blocked?(new_ip))
  end

  def test_turn_admin_on
    get(:turn_admin_on)
    assert_false(session[:admin])
    login(:rolf)
    get(:turn_admin_on)
    assert_false(session[:admin])
    rolf.admin = true
    rolf.save!
    get(:turn_admin_on)
    assert_true(session[:admin])
    get(:turn_admin_off)
    assert_false(session[:admin])
  end

  def test_switch_users
    get(:switch_users)
    assert_response(:redirect)
    login(:rolf)
    get(:switch_users)
    assert_response(:redirect)
    rolf.admin = true
    rolf.save!
    get(:switch_users)
    assert_response(:success)
    assert_users_equal(rolf, User.current)
    post(:switch_users, params: { id: "Frosted Flake" })
    assert_users_equal(rolf, User.current)
    post(:switch_users, params: { id: mary.id })
    assert_users_equal(mary, User.current)
    post(:switch_users, params: { id: dick.login })
    assert_users_equal(dick, User.current)
    post(:switch_users, params: { id: mary.email })
    assert_users_equal(mary, User.current)
  end
end
