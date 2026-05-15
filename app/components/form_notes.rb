# frozen_string_literal: true

# Notes section of a form, with a collapsible Bootstrap Panel wrap.
#
# Shared between forms that have user-configurable notes "parts"
# (currently observation; field-slip migration is in flight).
# Owns:
#   - The Panel (collapsible card with heading) — every form's notes
#     section renders inside this same wrap shape; callers don't
#     configure it beyond `panel_id:` and `expanded:`.
#   - A `<div id="...">` inside the panel body holding either an
#     empty-state-aware general-help paragraph plus a row of small
#     textareas (one per part), or a single 10-row textarea with an
#     inline help block (when `single_part_mode: true`).
#
# Callers normalize their domain parts (observation strings, field-slip
# `NotesFieldPart` objects, etc.) into uniform `Part` structs before
# passing — see `ObservationForm#observation_form_note_parts` for the
# canonical example.
class Components::FormNotes < Components::Base
  # Normalized shape for one notes part. `key` becomes the
  # Superform field key under `:notes` (`form[notes][<key>]`),
  # `value` is the current value, `label` is shown above the textarea.
  Part = Data.define(:key, :value, :label)

  prop :form, _Any
  prop :parts, Array
  # Panel id; also used to derive `#{panel_id}_inner` (collapse
  # target) and `#{panel_id}_fields` (the inner div the textareas
  # live in).
  prop :panel_id, String
  prop :expanded, _Boolean, default: false
  prop :indent, String, default: ""
  prop :single_part_mode, _Boolean, default: false
  # Override the default help block content (`:shared_textile_help.l`)
  # rendered in the panel's collapse target. ObservationForm uses this
  # in single-part mode to add the prose "what to put in notes" copy
  # on top of the textile help.
  prop :help_content, _Nilable(_Any), default: nil

  def view_template
    render(panel) do |p|
      p.with_heading { render_heading }
      p.with_body(collapse: true) { render_notes_inner }
    end
  end

  private

  def panel
    Components::Panel.new(
      panel_id: @panel_id,
      collapsible: true,
      collapse_target: "##{@panel_id}_inner",
      expanded: @expanded
    )
  end

  # Heading is "Notes" + a help-trigger icon that toggles the
  # collapse block in the body. `ml-2` puts a small gap between
  # title and trigger; the trigger has no built-in margin (its
  # usual placement is adjacent to a `<strong>` label that supplies
  # its own `mr-3`).
  def render_heading
    plain(:NOTES.l)
    CollapseInfoTrigger(target_id: help_target_id, extra_class: "ml-2")
  end

  def render_notes_inner
    div(id: "#{@panel_id}_fields") do
      # Collapse target lives in the body; the trigger in the heading
      # opens it via `target_id`. They don't have to be adjacent.
      CollapseHelpBlock(target_id: help_target_id) do
        help_block_content
      end
      div(class: @indent) do
        @form.namespace(:notes) do |notes_ns|
          @parts.each { |part| render_part(notes_ns, part) }
        end
      end
    end
  end

  # Default to bare textile help; callers (currently single-part-mode
  # observation) can supply richer copy that also explains what to put
  # in the notes field.
  def help_block_content
    @help_content || :shared_textile_help.l
  end

  # Derive the collapse target id from `panel_id` so multiple notes
  # panels on the same page don't share a target.
  def help_target_id
    "#{@panel_id}_help"
  end

  def render_part(notes_ns, part)
    render(notes_ns.field(part.key).textarea(
             wrapper_options: {
               label: part.label,
               # In single-part mode the panel heading already says
               # "Notes", so the textarea's visible label would be a
               # duplicate. Hide it visually but keep the
               # `<label for="…">` association for screen readers.
               label_sr_only: @single_part_mode
             },
             value: part.value,
             rows: row_count
           ))
  end

  def row_count
    @single_part_mode ? 10 : 1
  end
end
