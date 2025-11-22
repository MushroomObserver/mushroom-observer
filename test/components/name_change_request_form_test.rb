# frozen_string_literal: true

require "test_helper"

class NameChangeRequestFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @email = FormObject::NameChangeRequest.new
    @name = names(:coprinus_comatus)
    @new_name = "Agaricus foo"
    @new_name_with_icn_id = "#{@new_name}[#123456]"
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_help_text
    html = render_form

    assert_includes(html, :email_name_change_request_help.tp)
  end

  def test_renders_current_name_field
    html = render_form

    assert_includes(html, :NAME.t)
    assert_includes(html, @name.unique_search_name)
    assert_includes(html, "[##{@name.icn_id}]")
  end

  def test_renders_new_name_hidden_field
    html = render_form

    assert_includes(html, :new_name.t)
    assert_includes(html, @new_name_with_icn_id)
  end

  def test_renders_notes_field
    html = render_form

    assert_includes(html, :Notes.t)
    assert_html(html, "textarea[name='name_change_request[notes]']")
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
    form = Components::NameChangeRequestForm.new(
      @email,
      name: @name,
      new_name: @new_name,
      new_name_with_icn_id: @new_name_with_icn_id
    )
    # Stub url_for to avoid routing errors in test environment
    form.stub(:url_for, "/test_action") do
      render(form)
    end
  end
end
