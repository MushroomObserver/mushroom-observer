# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Licenses
  class FormTest < ComponentTestCase
    def setup
      super
      @license = License.new
      @html = render_form
    end

    def test_renders_form_with_display_name_field
      assert_html(@html, "label[for='license_display_name']",
                  text: :license_display_name.l)
      assert_html(@html,
                  "input[name='license[display_name]'][data-autofocus]")
    end

    def test_renders_form_with_url_field
      assert_html(@html, "label[for='license_url']",
                  text: :license_url.l)
      assert_html(@html, "input[name='license[url]']")
    end

    def test_renders_form_with_deprecated_checkbox
      assert_html(@html, "label[for='license_deprecated']",
                  text: :license_form_checkbox_deprecated.l)
      assert_html(@html,
                  "input[name='license[deprecated]'][type='checkbox']")
    end

    def test_renders_submit_button
      assert_html(@html, "button[type='submit']", text: :SUBMIT.t)
      assert_html(@html, ".btn.btn-default")
      assert_html(@html, ".center-block.my-3")
    end

    def test_form_has_correct_attributes_for_new_record
      assert_html(@html, "form[action='/licenses']")
      assert_html(@html, "form[method='post']")
    end

    def test_form_has_correct_attributes_for_existing_record
      @license = licenses(:ccnc25)
      html = render_form

      assert_html(html, "form[action='/licenses/#{@license.id}']")
      assert_html(html, "input[name='_method']")
      assert_html(html, "input[value='patch']")
    end

    private

    def render_form
      render(Form.new(@license))
    end
  end
end
