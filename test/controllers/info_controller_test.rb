# frozen_string_literal: true

require("test_helper")

# Controller tests for info pages
class InfoControllerTest < FunctionalTestCase

  def test_page_loads
    login
    get_with_dump(:how_to_help)
    assert_template(:how_to_help)

    get_with_dump(:how_to_use)
    assert_template(:how_to_use)

    get_with_dump(:intro)
    assert_template(:intro)

    get(:search_bar_help)
    assert_response(:success)

    get_with_dump(:news)
    assert_template(:news)

    get_with_dump(:textile)
    assert_template(:textile_sandbox)

    get_with_dump(:textile_sandbox)
    assert_template(:textile_sandbox)
  end

  def test_normal_permissions
    login
    get(:intro)
    assert_equal(200, @response.status)
    get(:textile_sandbox)
    assert_equal(200, @response.status)
  end

  def test_whitelisted_robot_permissions
    @request.user_agent =
      "Mozilla/5.0 (compatible; Googlebot/2.1; " \
      "+http://www.google.com/bot.html)"
    get(:intro) # authorized robots and anonymous users are allowed here
    assert_equal(200, @response.status)
    get(:textile_sandbox)
    assert_equal(403, @response.status)
  end

  def test_unauthorized_robot_permissions
    @request.user_agent =
      "Mozilla/5.0 (compatible; Baiduspider/2.0; "\
      "+http://www.baidu.com/search/spider.html)"
    get(:intro) # only authorized robots and anonymous users are allowed here
    assert_equal(403, @response.status)
  end

  def test_anon_user_how_to_use
    get(:how_to_use)

    assert_response(:success)
    assert_head_title(:how_title.l)
  end

  def test_anon_user_intro
    get(:intro)

    assert_response(:success)
    assert_head_title(:intro_title.l)
  end

  def test_site_stats
    login
    get(:site_stats)

    assert_select("title").text.include?(:show_site_stats_title.l)
    assert_select("#title", { text: :show_site_stats_title.l },
                  "Displayed title should be #{:show_site_stats_title.l}")
    assert(/#{:site_stats_contributing_users.l}/ =~ @response.body,
           "Page is missing #{:site_stats_contributing_users.l}")
  end

  # Prove w3c_tests renders html, with all content within the <body>
  # (and therefore without MO's layout).
  def test_w3c_tests
    login
    expect_start = "<html><head></head><body>"
    get(:w3c_tests)
    assert_equal(expect_start, @response.body[0..(expect_start.size - 1)])
  end

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
      assert_redirected_to(controller: :account, action: :login)

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
end
