# frozen_string_literal: true

require("test_helper")

module Views::Controllers::InatImports
  class ShowTest < ComponentTestCase
    def setup
      super
      @user = users(:katrina)
      controller.instance_variable_set(:@user, @user)
      @import = inat_imports(:katrina_inat_import)
    end

    def test_renders_status_component
      html = render_show

      assert_html(html, "#inat_import_#{@import.id}")
    end

    def test_context_nav_includes_index_link
      html = render_show

      assert_html(html, "a[href='#{routes.inat_imports_path}']")
    end

    private

    def render_show
      render(Show.new(inat_import: @import, user: @user))
    end
  end
end
