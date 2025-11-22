# frozen_string_literal: true

require "test_helper"

class MergeRequestEmailFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @email = FormObject::MergeRequest.new
    @old_name = names(:coprinus_comatus)
    @new_name = names(:agaricus_campestris)
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_help_text
    form = render_form

    assert_includes(form, :email_merge_request_help.tp(type: Name.type_tag))
  end

  def test_renders_old_object_field
    form = render_form

    assert_includes(form, :NAME.t)
    assert_includes(form, @old_name.unique_format_name.t)
  end

  def test_renders_new_object_field
    form = render_form

    assert_includes(form, @new_name.unique_format_name.t)
  end

  def test_renders_notes_field
    form = render_form

    assert_includes(form, :Notes.t)
    assert_includes(form, 'name="merge_request[notes]"')
    assert_includes(form, "rows=\"10\"")
    assert_includes(form, "data-autofocus")
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SEND.l)
    assert_includes(form, "center-block")
  end

  private

  def render_form
    form = Components::MergeRequestEmailForm.new(
      @email,
      old_obj: @old_name,
      new_obj: @new_name,
      model_class: Name
    )
    # Stub url_for to avoid routing errors in test environment
    form.stub(:url_for, "/test_action") do
      render(form)
    end
  end
end
