# frozen_string_literal: true

require "test_helper"

class NameTrackerFormTest < ComponentTestCase
  def setup
    super
    @name = names(:coprinus_comatus)
    @note_template = "Test template"
  end

  def test_new_tracker_form
    html = render_form(model: NameTracker.new(name: @name))

    # Submit button for new tracker
    assert_html(html, "input[type='submit'][value='#{:ENABLE.t}']")

    # Note template checkbox and help
    assert_html(html, "body", text: :email_tracking_note.l)
    assert_html(html, "input[name='name_tracker[note_template_enabled]']")
    assert_html(html, "body", text: :email_tracking_note_help.tp.as_displayed)

    # Note template textarea
    assert_html(html, "textarea[name='name_tracker[note_template]']")
    assert_html(html, "textarea[rows='16']")
    assert_html(html, "textarea[cols='80']")
    assert_html(html, "textarea[data-autofocus]")
  end

  def test_existing_tracker_form
    html = render_form(model: name_trackers(:coprinus_comatus_name_tracker))

    assert_html(html, "input[type='submit'][value='#{:UPDATE.t}']")
    assert_html(html, "input[type='submit'][value='#{:DISABLE.t}']")
  end

  private

  def render_form(model:)
    render(Components::NameTrackerForm.new(
             model,
             note_template: @note_template,
             action: "/test_action",
             id: "name_tracker_form"
           ))
  end
end
