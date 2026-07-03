# frozen_string_literal: true

require("test_helper")

module Views::Controllers::InatImports
  class ConfirmTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      @inat_import = inat_imports(:rolf_inat_import)
      @confirm_form = FormObject::InatImportConfirm.new(
        inat_username: "rolf_inat_username"
      )
    end

    def test_renders_confirm_form
      html = render_confirm

      assert_html(html, "form[action='#{routes.inat_imports_path}']")
      assert_html(html, "button[name='confirmed'][value='1']")
      assert_html(html, "button[name='go_back'][value='1']")
      assert_html(html,
                  "input[type='hidden'][name='inat_import_confirm" \
                  "[inat_username]']")
      assert_html(html, "#expected_count")
    end

    def test_renders_with_requested_count
      html = render_confirm(requested: 10)

      assert_html(html, "#requested_count")
    end

    private

    def render_confirm(requested: nil, unlicensed_obs: nil)
      render(Confirm.new(
               confirm_form: @confirm_form,
               inat_import: @inat_import,
               expected: 5,
               requested: requested,
               unlicensed_obs: unlicensed_obs
             ))
    end
  end
end
