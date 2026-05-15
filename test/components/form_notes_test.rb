# frozen_string_literal: true

require "test_helper"

# `Components::FormNotes` always renders a collapsible Bootstrap Panel
# wrapping the notes-fields content. The component is exercised here
# inside small test forms — same pattern as the parity tests in
# `application_form_helper_parity_test.rb`.
class FormNotesTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    User.current = @user
  end

  # --- Panel wrap is always present ---

  def test_renders_collapsible_panel_with_notes_heading
    html = render(MultiPartFormNotes.new(Observation.new, action: "/t"))

    # Panel uses panel_id as its outer element id.
    assert_html(html, "div#test_notes")
    # Heading slot is filled with the localized NOTES label.
    assert_includes(html, :NOTES.l)
    # Body collapse target is derived from panel_id.
    assert_html(html, "#test_notes_inner")
  end

  # --- Multi-part mode ---

  def test_multi_part_renders_general_help_and_one_textarea_per_part
    html = render(MultiPartFormNotes.new(Observation.new, action: "/t"))

    # Inner notes div derives id from panel_id.
    assert_html(html, "#test_notes_fields")
    # General-help paragraph (NOTES strong + collapse trigger + textile
    # help) appears in multi-part mode.
    assert_html(html, "#test_notes_fields > p strong", text: :NOTES.l)
    # One textarea per part, namespaced under `notes`, rows=1.
    assert_html(html,
                "textarea[name='observation[notes][habitat]'][rows='1']")
    assert_html(html,
                "textarea[name='observation[notes][substrate]'][rows='1']")
    # Each part's label appears (caller-supplied trailing colon).
    assert_includes(html, "Habitat notes:")
    assert_includes(html, "Substrate notes:")
  end

  def test_multi_part_respects_indent
    html = render(IndentedFormNotes.new(Observation.new, action: "/t"))

    # Inner div wrapping textareas gets the caller's indent class.
    assert_html(html, "#test_notes_fields > div.ml-5")
  end

  # --- Single-part mode ---

  def test_single_part_mode_renders_one_large_textarea_with_help
    html = render(SinglePartFormNotes.new(Observation.new, action: "/t"))

    # No general-help paragraph in single-part mode.
    assert_no_html(html, "#test_notes_fields > p strong")
    # The lone textarea is rows=10.
    assert_html(html,
                "textarea[name='observation[notes][other]'][rows='10']")
    # Caller-supplied help block renders via the textarea's help slot.
    assert_includes(html, "SINGLE_PART_HELP_MARKER")
  end
end

# --- Test form classes -------------------------------------------------

class MultiPartFormNotes < Components::ApplicationForm
  def view_template
    super do
      render(Components::FormNotes.new(
               form: self,
               parts: [
                 Components::FormNotes::Part.new(
                   key: :habitat, value: "", label: "Habitat notes:"
                 ),
                 Components::FormNotes::Part.new(
                   key: :substrate, value: "", label: "Substrate notes:"
                 )
               ],
               panel_id: "test_notes",
               expanded: true
             ))
    end
  end
end

class IndentedFormNotes < Components::ApplicationForm
  def view_template
    super do
      render(Components::FormNotes.new(
               form: self,
               parts: [
                 Components::FormNotes::Part.new(
                   key: :habitat, value: "", label: "Habitat:"
                 )
               ],
               panel_id: "test_notes",
               indent: "ml-5"
             ))
    end
  end
end

class SinglePartFormNotes < Components::ApplicationForm
  def view_template
    super do
      render(Components::FormNotes.new(
               form: self,
               parts: [
                 Components::FormNotes::Part.new(
                   key: :other, value: "", label: "Notes:"
                 )
               ],
               panel_id: "test_notes",
               expanded: true,
               single_part_mode: true,
               single_part_help: "SINGLE_PART_HELP_MARKER".html_safe
             ))
    end
  end
end
