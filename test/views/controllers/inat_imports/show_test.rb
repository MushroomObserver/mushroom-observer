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

    def test_results_link_navigates_to_observations
      html = render_show

      # GET link — rendered as <a> by Button::Get
      assert_html(html, "a[href*='/observations'][href*='pattern=']")
    end

    def test_cancel_button_submits_put_to_cancel_path
      html = render_show

      cancel_path = routes.inat_import_cancel_path(id: @import.id)
      assert_html(html, "form[action='#{cancel_path}']")
      assert_html(html, "input[name='_method'][value='put']")
    end

    private

    def render_show
      render(Show.new(inat_import: @import, user: @user))
    end
  end
end
