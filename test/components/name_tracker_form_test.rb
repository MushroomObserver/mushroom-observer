# frozen_string_literal: true

require "test_helper"

class NameTrackerFormTest < ComponentTestCase
  def setup
    super
    @name = names(:coprinus_comatus)
    @note_template = "Test template"
  end

  def test_renders_enable_button_for_new_tracker
    html = render_form_for_new_tracker

    assert_html(html, "input[type='submit'][value='#{:ENABLE.t}']")
  end

  def test_renders_update_and_disable_buttons_for_existing_tracker
    html = render_form_for_existing_tracker

    assert_html(html, "input[type='submit'][value='#{:UPDATE.t}']")
    assert_html(html, "input[type='submit'][value='#{:DISABLE.t}']")
  end

  def test_renders_note_template_checkbox
    html = render_form

    assert_html(html, "body", text: :email_tracking_note.l)
    assert_html(html, "input[name='name_tracker[note_template_enabled]']")
  end

  def test_renders_note_template_help
    html = render_form

    assert_html(html, "body", text: :email_tracking_note_help.tp.as_displayed)
  end

  def test_renders_note_template_textarea
    html = render_form

    assert_html(html, "textarea[name='name_tracker[note_template]']")
    assert_html(html, "textarea[rows='16']")
    assert_html(html, "textarea[cols='80']")
    assert_html(html, "textarea[data-autofocus]")
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
