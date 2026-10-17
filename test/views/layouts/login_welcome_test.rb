# frozen_string_literal: true

require("test_helper")

module Views::Layouts
  class LoginWelcomeTest < ComponentTestCase
    def test_renders_welcome_banner
      html = render_component

      assert_html(html, ".d-block.d-sm-none")
      assert_html(html, "img.logo-trim[alt='MO Logo'][src='/logo-trim.png']")
      assert_includes(html, "Mushroom Observer (MO)")
      assert_includes(html, :login_layout_description.t)
      assert_html(html, ".container-text")
      assert_includes(html, "<!-- LOGIN WELCOME -->")
      assert_includes(html, "<!-- /LOGIN WELCOME -->")
    end

    private

    def render_component
      render(LoginWelcome.new)
    end
  end
end
