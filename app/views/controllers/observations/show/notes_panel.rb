# frozen_string_literal: true

class Views::Controllers::Observations::Show::NotesPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    return if @obs.notes == ::Observation.no_notes

    Panel(panel_id: "observation_notes") do |panel|
      panel.with_heading { :NOTES.l }
      panel.with_body { render_notes }
    end
  end

  # Passes each notes value to textile independently rather than
  # the whole block — a `+photo` value at the start of a line
  # would otherwise be interpreted as textile bold-emphasis across
  # subsequent lines.
  def render_notes
    div(class: "obs-notes textile") do
      # ApplicationController resets the per-request Textile cache
      # before every action; this only needs to prime it.
      ::Textile.register_name(@obs.name)
      render_note_values(@obs.notes)
    end
  end

  # "Other"-only notes show just the value (MO omits the lone "Other"
  # caption); multi-part notes show each caption with its value indented
  # beneath it. Values render via `.tpl` (full textile) so blank lines
  # survive as paragraph breaks — `.tl` keeps only the first paragraph
  # and would truncate the note at its first blank line (#4536).
  def render_note_values(notes)
    if notes.keys == [:Other]
      trusted_html(notes[:Other].to_s.tpl)
    else
      notes.each { |key, value| render_note_part(key, value) }
    end
  end

  def render_note_part(key, value)
    trusted_html("+#{key.to_s.tr("_", " ")}+:".tl)
    div(class: "indent") { trusted_html(value.to_s.tpl) }
  end
end
