# frozen_string_literal: true

require("test_helper")

module Views::Controllers::InatImports
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
    end

    def test_default_form_shows_all_method_selected
      html = render_form

      # All radio is checked by default
      assert_html(html,
                  "input[type='radio'][value='all']" \
                  "[name='inat_import[choose_method]'][checked]")
      # IDs and URL radios are not checked
      assert_no_html(html,
                     "input[type='radio'][value='ids'][checked]")
      assert_no_html(html,
                     "input[type='radio'][value='url'][checked]")
    end

    def test_default_form_panels_start_closed
      html = render_form

      # Neither collapse panel is open (no .in class)
      assert_no_html(html, "[data-type-switch-type='ids'].in")
      assert_no_html(html, "[data-type-switch-type='url'].in")
    end

    def test_ids_method_opens_ids_panel
      html = render_form(choose_method: "ids", inat_ids: "123 456")

      assert_html(html,
                  "input[type='radio'][value='ids'][checked]")
      assert_html(html, "[data-type-switch-type='ids'].in")
      assert_no_html(html, "[data-type-switch-type='url'].in")
    end

    def test_url_method_opens_url_panel
      html = render_form(choose_method: "url", inat_url: "https://inat.org")

      assert_html(html,
                  "input[type='radio'][value='url'][checked]")
      assert_html(html, "[data-type-switch-type='url'].in")
      assert_no_html(html, "[data-type-switch-type='ids'].in")
    end

    def test_type_switch_controller_wired
      html = render_form

      assert_html(html, "[data-controller='type-switch']")
      assert_html(html,
                  "input[type='radio']" \
                  "[data-action='change->type-switch#switch']",
                  count: 3)
    end

    def test_ids_field_name_and_help
      html = render_form(choose_method: "ids")

      assert_html(html, "textarea[name='inat_import[inat_ids]']")
      assert_html(html, "[data-type-switch-type='ids'] .help-block")
    end

    def test_url_field_name_and_help
      html = render_form(choose_method: "url")

      assert_html(html, "[name='inat_import[inat_url]']")
      assert_html(html, "[data-type-switch-type='url'] .help-block")
      assert_html(html,
                  "[name='inat_import[inat_url]']" \
                  "[placeholder*='inaturalist.org']")
    end

    def test_username_field
      html = render_form

      assert_html(html, "input[name='inat_import[inat_username]']")
    end

    def test_consent_checkbox
      html = render_form

      assert_html(html,
                  "input[type='checkbox']" \
                  "[name='inat_import[consent]']")
    end

    def test_recheck_all_checkbox
      html = render_form

      assert_html(html,
                  "input[type='checkbox'][name='inat_import[recheck_all]']")
      assert_includes(html, :inat_recheck_all.l)
    end

    def test_super_importer_field_hidden_by_default
      html = render_form(super_importer: false)

      assert_no_html(html, "input[name='inat_import[import_others]']")
    end

    def test_super_importer_field_shown_when_enabled
      html = render_form(super_importer: true)

      assert_html(html, "input[name='inat_import[import_others]']")
    end

    def test_submit_posts_to_inat_imports_path
      html = render_form

      assert_html(html,
                  "form[action='#{routes.inat_imports_path}']")
    end

    private

    def render_form(choose_method: "all", inat_ids: nil,
                    inat_url: nil, super_importer: false)
      model = FormObject::InatImport.new(
        inat_username: @user.inat_username,
        choose_method: choose_method,
        inat_ids: inat_ids,
        inat_url: inat_url
      )
      render(Form.new(model, super_importer: super_importer,
                             local: true))
    end
  end
end
