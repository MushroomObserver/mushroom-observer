# frozen_string_literal: true

require "test_helper"

class LicenseFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @license = License.new
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_display_name_field
    assert_html(@html, "body", text: :license_display_name.l)
    assert_html(@html, "input[name='license[display_name]']")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_form_with_url_field
    assert_html(@html, "body", text: :license_url.l)
    assert_html(@html, "input[name='license[url]']")
  end

  def test_renders_form_with_deprecated_checkbox
    assert_html(@html, "body", text: :license_form_checkbox_deprecated.l)
    assert_html(@html, "input[name='license[deprecated]']")
    assert_html(@html, "input[type='checkbox']")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SUBMIT.t}']")
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
    form = Components::LicenseForm.new(@license)
    render(form)
  end
end
