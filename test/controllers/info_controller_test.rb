# frozen_string_literal: true

require("test_helper")

# Controller tests for info pages
class InfoControllerTest < FunctionalTestCase
  def test_page_loads
    login
    get(:how_to_help)
    assert_template(:how_to_help)

    get(:how_to_use)
    assert_template(:how_to_use)

    get(:intro)
    assert_template(:intro)

    get(:search_bar_help)
    assert_response(:success)

    get(:news)
    assert_template(:news)

    get(:textile_sandbox)
    assert_template(:textile_sandbox)
  end

  def test_normal_permissions
    login
    get(:intro)
    assert_equal(200, @response.status)
    get(:textile_sandbox)
    assert_equal(200, @response.status)
  end

  def test_allowed_robot_permissions
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
      "Mozilla/5.0 (compatible; Baiduspider/2.0; " \
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
end
