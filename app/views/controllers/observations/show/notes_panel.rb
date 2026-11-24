# frozen_string_literal: true

class Views::Controllers::Observations::Show::NotesPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    render_regular_notes_panel
    render_inat_panel
  end

  private

  def notes
    @notes ||= @obs.display_notes
  end

  # Every part except the iNat import snapshot, which gets a separate
  # panel below instead.
  def regular_notes
    @regular_notes ||= notes.except(inat_snapshot_key)
  end

  # A lone blank "Other" value isn't content -- without this check an
  # iNat-only observation (regular_notes == { Other: "" }) would still
  # render an empty Notes panel above the iNat one.
  def regular_notes_present?
    return false if regular_notes.blank?
    return true unless regular_notes.keys == [:Other]

    regular_notes[:Other].to_s.present?
  end

  def inat_value
    notes[inat_snapshot_key]
  end

  def inat_snapshot_key
    ::Observation.inat_snapshot_key
  end

  def render_regular_notes_panel
    return unless regular_notes_present?

    Panel(id: "observation_notes") do |panel|
      panel.with_heading { :notes.ti }
      panel.with_body { render_notes_body(regular_notes) }
    end
  end

  # A separate panel, collapsed by default -- the iNat snapshot can
  # run long (an embedded DNA sequence line, for instance), and is
  # conceptually distinct from the observer's notes even though both
  # are stored in the same notes column.
  def render_inat_panel
    return if inat_value.blank?

    Panel(id: "observation_inat_snapshot", collapsible: true,
          collapse_target: "#observation_inat_snapshot_body",
          expanded: false) do |panel|
      panel.with_heading { plain(:inat_snapshot_caption.ti) }
      panel.with_body(collapse: true) do
        render_notes_body({ Other: inat_value })
      end
    end
  end

  # Passes each notes value to textile independently rather than
  # the whole block — a `+photo` value at the start of a line
  # would otherwise be interpreted as textile bold-emphasis across
  # subsequent lines.
  def render_notes_body(parts)
    div(class: "obs-notes textile") do
      # ApplicationController resets the per-request Textile cache
      # before every action; this only needs to prime it.
      ::Textile.register_name(@obs.name)
      render_note_values(parts)
    end
  end

  # "Other"-only notes show just the value (MO omits the lone "Other"
  # caption); multi-part notes show each caption with its value indented
  # beneath it. Values render via `.tpl` (full textile) so blank lines
  # survive as paragraph breaks — `.tl` keeps only the first paragraph
  # and would truncate the note at its first blank line (#4536).
  def render_note_values(parts)
    if parts.keys == [:Other]
      trusted_html(parts[:Other].to_s.tpl)
    else
      parts.each { |key, value| render_note_part(key, value) }
    end
  end

  def render_note_part(key, value)
    return if key == :Other && value.to_s.blank?

    trusted_html(append_colon("+#{key.to_s.tr("_", " ")}+").tl)
    div(class: "indent") { trusted_html(value.to_s.tpl) }
  end
end
