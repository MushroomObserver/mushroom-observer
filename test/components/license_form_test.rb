# frozen_string_literal: true

require "test_helper"

class LicenseFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @license = License.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_display_name_field
    form = render_form

    assert_includes(form, :license_display_name.t)
    assert_includes(form, 'name="license[display_name]"')
    assert_includes(form, "data-autofocus")
  end

  def test_renders_form_with_url_field
    form = render_form

    assert_includes(form, :license_url.t)
    assert_includes(form, 'name="license[url]"')
  end

  def test_renders_form_with_deprecated_checkbox
    form = render_form

    assert_includes(form, :license_form_checkbox_deprecated.t)
    assert_includes(form, 'name="license[deprecated]"')
    assert_includes(form, 'type="checkbox"')
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SUBMIT.t)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
  end

  def test_form_has_correct_attributes_for_new_record
    form = render_form

    assert_includes(form, 'action="/licenses"')
    assert_includes(form, 'method="post"')
  end

  def test_form_has_correct_attributes_for_existing_record
    @license = licenses(:ccnc25)
    form = render_form

    assert_includes(form, "action=\"/licenses/#{@license.id}\"")
    assert_includes(form, 'name="_method"')
    assert_includes(form, 'value="patch"')
  end

  private

  def render_form
    form = Components::LicenseForm.new(@license)
    render(form)
  end
end
