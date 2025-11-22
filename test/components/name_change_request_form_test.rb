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
    form = render_form

    assert_includes(form, :email_name_change_request_help.tp)
  end

  def test_renders_current_name_field
    form = render_form

    assert_includes(form, :NAME.t)
    assert_includes(form, @name.unique_search_name)
    assert_includes(form, "[##{@name.icn_id}]")
  end

  def test_renders_new_name_hidden_field
    form = render_form

    assert_includes(form, :new_name.t)
    assert_includes(form, @new_name_with_icn_id)
  end

  def test_renders_notes_field
    form = render_form

    assert_includes(form, :Notes.t)
    assert_includes(form, 'name="name_change_request[notes]"')
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
