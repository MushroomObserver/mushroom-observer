# frozen_string_literal: true

require "test_helper"

class MergeRequestFormTest < ComponentTestCase
  def setup
    super
    @email = FormObject::EmailRequest.new
    @old_name = names(:coprinus_comatus)
    @new_name = names(:agaricus_campestris)
  end

  def test_renders_form_with_help_text
    html = render_form

    assert_html(
      html, "body",
      text: :email_merge_request_help.tp(type: Name.type_tag).as_displayed
    )
  end

  def test_renders_old_object_field
    html = render_form

    assert_html(html, "body", text: :NAME.l)
    assert_includes(html, @old_name.unique_format_name.t)
  end

  def test_renders_new_object_field
    html = render_form

    assert_includes(html, @new_name.unique_format_name.t)
  end

  def test_renders_message_field
    html = render_form

    assert_html(html, "body", text: :Notes.l)
    assert_html(html, "textarea[name='email[message]']")
    assert_html(html, "textarea[rows='10']")
    assert_html(html, "textarea[data-autofocus]")
  end

  def test_renders_submit_button
    html = render_form

    assert_html(html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(html, ".center-block")
  end

  private

  def render_form
    form = Components::MergeRequestForm.new(
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
