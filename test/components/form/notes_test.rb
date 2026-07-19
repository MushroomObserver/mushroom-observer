# frozen_string_literal: true

require "test_helper"

# `Components::Form::Notes` always renders a collapsible Bootstrap Panel
# wrapping the notes-fields content. The component is exercised here
# inside small test forms — same pattern as the parity tests in
# `application_form_helper_parity_test.rb`.
class FormNotesTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  # --- Panel wrap is always present ---

  def test_renders_collapsible_panel_with_notes_heading
    html = render(MultiPartFormNotes.new(Observation.new, action: "/t"))

    # Panel uses panel_id as its outer element id.
    assert_html(html, "div#test_notes")
    # Heading slot is filled with the localized NOTES label and
    # nothing else — no help icon or collapse trigger in the heading.
    assert_includes(html, :NOTES.l)
    assert_no_html(html, ".panel-heading a.info-collapse-trigger",
                   "no in-header help trigger — help is inline in body")
    # Body collapse target is derived from panel_id.
    assert_html(html, "#test_notes_inner")
  end

  # --- Multi-part mode ---

  def test_multi_part_renders_textareas_and_textile_help_below
    html = render(MultiPartFormNotes.new(Observation.new, action: "/t"))

    # Inner notes div derives id from panel_id.
    assert_html(html, "#test_notes_fields")
    # One textarea per part, namespaced under `notes`, rows=1.
    assert_html(html,
                "textarea[name='observation[notes][habitat]'][rows='1']")
    assert_html(html,
                "textarea[name='observation[notes][substrate]'][rows='1']")
    # Each part's label appears (caller-supplied trailing colon).
    assert_includes(html, "Habitat notes:")
    assert_includes(html, "Substrate notes:")
    # Textile help is always rendered at the bottom of the body.
    assert_html(html, "#test_notes_fields div.help-block")
    # No `above_help` in multi-part mode even if the caller passes
    # one — multi-part users typically know what each field is for.
    # `.help-block` here is used as the IDENTIFIER of the textile-
    # help div (no other selector marks it). Per the cosmetic-
    # classes rule, identifier classes that mark a specific
    # element are fair game; pure decoration is not.
    assert_no_html(html,
                   "#test_notes_fields > div.help-block:first-child")
  end

  def test_multi_part_textile_help_renders_below_textareas
    html = render(MultiPartFormNotes.new(Observation.new, action: "/t"))

    # The textile help is the last child of the notes-fields div,
    # below all the textareas (not above them).
    fields_div = Nokogiri::HTML5.fragment(html).at_css("#test_notes_fields")
    last_child = fields_div.element_children.last
    assert_equal("div", last_child.name)
    assert_includes(last_child["class"] || "", "help-block")
  end

  # --- Single-part mode ---

  def test_single_part_mode_renders_one_large_textarea
    html = render(SinglePartFormNotes.new(Observation.new, action: "/t"))

    # The lone textarea is rows=10.
    assert_html(html,
                "textarea[name='observation[notes][other]'][rows='10']")
    # Textarea label exists for screen readers but is visually hidden:
    # the panel heading already says "Notes", so the field's own
    # visible label would be a duplicate. `.sr-only` IS a visibility
    # behavior class (per the cosmetic-classes rule, behavior classes
    # are kept) — it's what makes the label invisible-to-sighted-users.
    assert_html(html, "label.sr-only[for='observation_notes_other']")
  end

  def test_single_part_mode_renders_above_help_above_textarea
    html = render(SinglePartFormNotes.new(Observation.new, action: "/t"))

    # Caller-supplied prose help renders ABOVE the textarea, inline
    # (no collapse wrapping — visible whenever the panel is open).
    assert_includes(html, "ABOVE_HELP_MARKER")
    above_help_pos = html.index("ABOVE_HELP_MARKER")
    textarea_pos = html.index("<textarea")
    assert(above_help_pos < textarea_pos,
           "above_help must render before the textarea")
  end

  def test_single_part_mode_textile_help_renders_below_textarea
    html = render(SinglePartFormNotes.new(Observation.new, action: "/t"))

    # Textile help still renders below the textarea — same as
    # multi-part mode. Above-help is the only extra in single-part.
    # The notes-fields body div's children, in order:
    #   [0] above_help  [1] textareas-wrap  [2] textile help-block
    fields = Nokogiri::HTML5.fragment(html).at_css("#test_notes_fields")
    children = fields.element_children
    assert_equal(3, children.size,
                 "expected above-help, textareas wrap, textile help")
    assert_includes(children.first["class"] || "", "help-block",
                    "first child should be the above-help block")
    assert_includes(children.last["class"] || "", "help-block",
                    "last child should be the textile help block")
  end

  # --- Occurrence value-source buttons ---

  # For each shared key the primary shows value + action buttons: a
  # button per available value (its own, then each sibling's, carrying
  # the raw value beside the shown preview), then Inherit / Hide / All.
  # The button for the current state is active; the textarea reflects it.
  def test_occurrence_rows_render_value_and_action_buttons
    html = render(OccurrenceFormNotes.new(Observation.new, action: "/t"))

    assert_html(html, "[data-controller='notes-adopt']")

    # Textarea states: :set editable, :inherit disabled, :hide readonly.
    assert_no_html(html, "textarea[name='observation[notes][cap]'][disabled]")
    assert_html(html, "[data-notes-row] " \
                      "textarea[name='observation[notes][substrate]']" \
                      "[disabled][data-notes-adopt-target='value']")
    assert_html(html, "textarea[name='observation[notes][odor]'][readonly]")

    # :inherit shows the inherited value greyed (disabled), and the row
    # carries it so a click can restore it.
    assert_html(html, "textarea[name='observation[notes][substrate]']",
                text: "wood")
    assert_html(html,
                "[data-notes-row][data-notes-inherited-value='wood']")

    # "This Observation" button only where the primary stores a value
    # (cap), active, carrying the raw value; siblings carry theirs.
    assert_html(html, "button[data-notes-action='current']" \
                      "[data-notes-value='red'].active",
                text: :form_observations_notes_this_observation.l, count: 1)
    assert_html(html, "button[data-notes-action='adopt']" \
                      "[data-notes-value='brown']", text: "Obs 5")
    # Screen readers announce the value via the button's aria-label,
    # since the shown value lives in a separate span.
    assert_html(html, "button[data-notes-action='adopt']" \
                      "[aria-label='Obs 5: brown']")
    assert_html(html, "button[data-notes-action='adopt']" \
                      "[data-notes-value='wood']", text: "Obs 123")

    # Active state per row: cap -> current, substrate -> inherit,
    # odor -> hide.
    assert_html(html, "button[data-notes-action='inherit'].active", count: 1)
    assert_html(html, "button[data-notes-action='hide'].active", count: 1)

    # "All" only where there are 2+ values: cap (own + brown) and
    # substrate (wood + bark), not odor (one sibling value).
    assert_html(html, "button[data-notes-action='concatenate']",
                text: :form_observations_notes_all.l, count: 2)

    # The label still associates with the textarea.
    assert_html(html, "label[for='observation_notes_cap']", text: "Cap")
  end

  def test_no_adopt_controller_without_adopt_options
    html = render(MultiPartFormNotes.new(Observation.new, action: "/t"))

    assert_no_html(html, "[data-controller='notes-adopt']")
  end

  # A shared key whose value agrees across observations (empty
  # adopt_options) still gets the buttons -- This Observation (active)
  # plus Inherit/Hide -- but no sibling to adopt and no All (one value).
  def test_agreeing_shared_key_still_renders_buttons
    html = render(AgreeingKeyFormNotes.new(Observation.new, action: "/t"))

    assert_html(html, "[data-controller='notes-adopt']")
    assert_html(html, "button[data-notes-action='current']" \
                      "[data-notes-value='white'].active")
    assert_html(html, "button[data-notes-action='inherit']")
    assert_html(html, "button[data-notes-action='hide']")
    assert_no_html(html, "button[data-notes-action='adopt']")
    assert_no_html(html, "button[data-notes-action='concatenate']")
  end
end

# --- Test form classes -------------------------------------------------

# One shared key whose values agree: :set with empty adopt_options.
class AgreeingKeyFormNotes < Components::ApplicationForm
  def view_template
    super do
      render(Components::Form::Notes.new(
               form: self,
               parts: [
                 Components::Form::Notes::Part.new(
                   key: :gills, value: "white", label: "gills",
                   adopt_options: [], notes_state: :set
                 )
               ],
               panel_id: "test_notes",
               expanded: true
             ))
    end
  end
end

class MultiPartFormNotes < Components::ApplicationForm
  def view_template
    super do
      render(Components::Form::Notes.new(
               form: self,
               parts: [
                 Components::Form::Notes::Part.new(
                   key: :habitat, value: "", label: "Habitat notes:"
                 ),
                 Components::Form::Notes::Part.new(
                   key: :substrate, value: "", label: "Substrate notes:"
                 )
               ],
               panel_id: "test_notes",
               expanded: true
             ))
    end
  end
end

class SinglePartFormNotes < Components::ApplicationForm
  def view_template
    super do
      render(Components::Form::Notes.new(
               form: self,
               parts: [
                 Components::Form::Notes::Part.new(
                   key: :other, value: "", label: "Notes:"
                 )
               ],
               panel_id: "test_notes",
               expanded: true,
               single_part_mode: true,
               above_help: "ABOVE_HELP_MARKER".html_safe
             ))
    end
  end
end

# One of each occurrence value-source state: :set (cap, owns a value),
# :inherit (substrate, owns nothing), :hide (odor, owns a blank).
class OccurrenceFormNotes < Components::ApplicationForm
  def view_template
    super do
      render(Components::Form::Notes.new(
               form: self,
               parts: [
                 Components::Form::Notes::Part.new(
                   key: :cap, value: "red", label: "Cap",
                   adopt_options: [[5, "brown"]], notes_state: :set
                 ),
                 Components::Form::Notes::Part.new(
                   key: :substrate, value: "", label: "substrate",
                   adopt_options: [[123, "wood"], [124, "bark"]],
                   notes_state: :inherit, inherited_value: "wood"
                 ),
                 Components::Form::Notes::Part.new(
                   key: :odor, value: "", label: "odor",
                   adopt_options: [[7, "pungent"]], notes_state: :hide
                 )
               ],
               panel_id: "test_notes",
               expanded: true
             ))
    end
  end
end
