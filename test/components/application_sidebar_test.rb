# frozen_string_literal: true

require "test_helper"

class ApplicationSidebarTest < ComponentTestCase
  Browser = Struct.new(:bot?) do
    def bot?
      self[:bot?]
    end
  end
  Request = Struct.new(:url)

  def setup
    super
    @user = users(:rolf)
  end

  def test_renders_logo_for_human
    html = render_component

    assert_html(html, "a#logo_link[href='/']")
    assert_html(html, "img.logo-trim[alt='Mushroom Observer Logo']")
  end

  def test_renders_logo_for_bot
    html = render_component(browser: bot_browser)

    assert_html(html, "a#logo_link[href='/sitemap/index.html']")
  end

  def test_renders_login_section_for_guest
    html = render_component(user: nil)

    # Should have login section
    assert_includes(html, :app_account.t)
    assert_includes(html, "nav_login_link")
    assert_includes(html, "nav_signup_link")

    # Should NOT have admin section
    assert_not_includes(html, :app_admin.t)
  end

  def test_renders_admin_section_in_admin_mode
    html = render_component(in_admin_mode: true)

    # Should have admin section
    assert_includes(html, :app_admin.t)
    assert_includes(html, "nav_admin_off_link")

    # Should NOT have login section
    assert_not_includes(html, "nav_login_link")
  end

  def test_renders_user_sections_for_logged_in_user
    html = render_component

    # Should have user section (mobile only)
    assert_includes(html, @user.login)
    assert_includes(html, "nav_user_logout_link")

    # Should have observations section
    assert_includes(html, :app_observations_left.t)

    # Should have species lists section
    assert_includes(html, :app_species_list.t)
  end

  def test_renders_info_sections
    html = render_component

    # Should have latest section
    assert_includes(html, :app_latest.t)

    # Should have indexes section (for logged-in users)
    assert_includes(html, :INDEXES.t)

    # Should have info section
    assert_includes(html, :app_more.t)

    # Should have languages dropdown
    assert_includes(html, :app_languages.t)
  end

  def test_hides_indexes_for_guests
    html = render_component(user: nil)

    # Should NOT have indexes section
    assert_not_includes(html, :INDEXES.t)
  end

  def test_has_nav_active_controller
    html = render_component

    assert_html(html, "div[data-controller='nav-active']")
  end

  def test_has_sidebar_structure
    html = render_component

    assert_html(html, "nav#sidebar.sidebar-offcanvas")
    assert_html(html, "div#navigation")
  end

  private

  def render_component(user: @user, browser: human_browser,
                       in_admin_mode: false)
    render(
      Components::ApplicationSidebar.new(
        user: user,
        browser: browser,
        request: mock_request,
        in_admin_mode: in_admin_mode
      )
    )
  end

  def human_browser
    Browser.new(false)
  end

  def bot_browser
    Browser.new(true)
  end

  def mock_request
    Request.new("http://example.com/path")
  end
end
