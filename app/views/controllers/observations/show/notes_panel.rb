# frozen_string_literal: true

class Views::Controllers::Observations::Show::NotesPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    return if @obs.display_notes == ::Observation.no_notes

    Panel(**panel_attrs) do |panel|
      panel.with_heading { :notes.ti }
      panel.with_body { render_regular_notes } if regular_notes.present?
      render_inat_section(panel) if inat_value
    end
  end

  # Panel's per-body collapse: true always targets the panel's
  # collapse_target:/expanded: props (Components::Panel#
  # render_collapse_body reads @collapse_id, ignoring any id: passed
  # to with_body) -- collapsible: is left unset so the top "Notes"
  # heading doesn't also grow a toggle pointed at the same target.
  def panel_attrs
    attrs = { id: "observation_notes" }
    return attrs unless inat_value

    attrs.merge(collapse_target: "##{inat_collapse_id}", expanded: false)
  end

  private

  def notes
    @notes ||= @obs.display_notes
  end

  # Every part except the iNat import snapshot, which gets a
  # collapsible sub-section below instead.
  def regular_notes
    @regular_notes ||= notes.except(inat_snapshot_key)
  end

  def inat_value
    notes[inat_snapshot_key]
  end

  # The key this part is stored under is derived from this same
  # translation at import time (Inat::Obs#snapshot_key) -- comparing
  # against it, rather than a hardcoded key, keeps the two in sync.
  def inat_snapshot_key
    ::Observation.notes_normalized_key(:inat_snapshot_caption.l)
  end

  def inat_collapse_id
    "obs_note_#{inat_snapshot_key}"
  end

  # Passes each notes value to textile independently rather than
  # the whole block — a `+photo` value at the start of a line
  # would otherwise be interpreted as textile bold-emphasis across
  # subsequent lines.
  def render_regular_notes
    div(class: "obs-notes textile") do
      # ApplicationController resets the per-request Textile cache
      # before every action; this only needs to prime it.
      ::Textile.register_name(@obs.name)
      render_note_values(regular_notes)
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

  # A second panel-heading-styled section, collapsed by default --
  # the iNat snapshot can run long (an embedded DNA sequence line, for
  # instance). Mirrors Components::Panel's collapsible-heading shape
  # (plain heading text, a caret-only trigger) rather than Panel's
  # built-in collapsible: option, which supports only one collapsible
  # body per panel.
  def render_inat_section(panel)
    panel.with_body(wrapper: false) { render_inat_heading }
    panel.with_body(collapse: true) do
      ::Textile.register_name(@obs.name)
      div(class: "indent textile") { trusted_html(inat_value.to_s.tpl) }
    end
  end

  def render_inat_heading
    div(class: "panel-heading") do
      div(class: "h4 panel-title d-flex justify-content-between " \
                 "align-items-center") do
        span { plain(:inat_snapshot_caption.ti) }
        render_inat_collapse_trigger
      end
    end
  end

  def render_inat_collapse_trigger
    Link(type: :collapse_toggle, target_id: inat_collapse_id,
         class: "panel-collapse-trigger ml-3 inline-flex-center") do
      Icon(type: :chevron_down, title: :open.ti, class: "active-icon",
           center_tooltip: true)
      Icon(type: :chevron_up, title: :close.ti, center_tooltip: true)
    end
  end
end
