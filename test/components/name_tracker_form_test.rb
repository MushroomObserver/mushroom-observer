# frozen_string_literal: true

require "test_helper"

class NameTrackerFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @name = names(:coprinus_comatus)
    @note_template = "Test template"
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_enable_button_for_new_tracker
    form = render_form_for_new_tracker

    assert_includes(form, :ENABLE.t)
  end

  def test_renders_update_and_disable_buttons_for_existing_tracker
    form = render_form_for_existing_tracker

    assert_includes(form, :UPDATE.t)
    assert_includes(form, :DISABLE.t)
  end

  def test_renders_note_template_checkbox
    form = render_form

    assert_includes(form, :email_tracking_note.t)
    assert_includes(form,
                    'name="name_tracker[name_tracker][note_template_enabled]"')
  end

  def test_renders_note_template_help
    form = render_form

    assert_includes(form, :email_tracking_note_help.t)
  end

  def test_renders_note_template_textarea
    form = render_form

    assert_includes(form, 'name="name_tracker[name_tracker][note_template]"')
    assert_includes(form, "rows=\"16\"")
    assert_includes(form, "cols=\"80\"")
    assert_includes(form, "data-autofocus")
  end

  private

  def render_form_for_new_tracker
    tracker = NameTracker.new(name: @name)
    form = Components::NameTrackerForm.new(
      tracker,
      note_template: @note_template,
      action: "/test_action",
      id: "name_tracker_form"
    )
    render(form)
  end

  def render_form_for_existing_tracker
    tracker = name_trackers(:coprinus_comatus_name_tracker)
    form = Components::NameTrackerForm.new(
      tracker,
      note_template: @note_template,
      action: "/test_action",
      id: "name_tracker_form"
    )
    render(form)
  end

  def render_form
    # For tests that don't care about new vs existing
    render_form_for_new_tracker
  end
end
