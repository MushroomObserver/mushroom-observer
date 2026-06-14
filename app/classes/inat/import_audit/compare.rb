# frozen_string_literal: true

module Inat::ImportAudit
  # Pure, stateless helpers for the import audit: computing the "reimport
  # delta" (MO-side content a fresh import would not regenerate) and parsing
  # the stored snapshot.
  module Compare
    # Note keys the importer itself writes; everything else is MO-native.
    IMPORTER_NOTE_KEYS = %w[iNat_imported_data Other].freeze

    # MO-auto-generated note fragments a reimport regenerates from
    # associations (field slips, occurrences, back-links) - not user-authored,
    # so they're stripped from the residual. See the migration design note.
    REGENERABLE = Regexp.union(
      /Field slip:\s*\S+/i,
      %r{https?://(?:www\.)?mushroomobserver\.org/\S*}i,
      /Imported by Mushroom Observer\s+\d{4}-\d{2}-\d{2}/i,
      # MO "<date>: Previous location: <loc>" annotation, date prefix included.
      /;?\s*\d{4}-\d{2}-\d{2}:\s*Previous location:[^|]*/i
    )

    def norm(str)
      str.to_s.gsub(/\s+/, " ").strip
    end

    # Drop the blank-line markers and collapse to a single normalized blob.
    def scrub(str)
      norm(str.to_s.gsub(/<!--.*?-->/m, " "))
    end

    # The part of MO's :Other a reimport would NOT regenerate: the MO notes
    # blob minus the current iNat description (what reimport rewrites) and
    # minus MO-auto-generated fragments. A non-empty residual is the ambiguous
    # notes case (genuinely MO-authored content mixed into :Other).
    def other_residual(mo_other, inat_clean)
      mo = scrub(mo_other)
      return "" if mo.blank?

      inat = scrub(inat_clean)
      residual = inat.present? ? mo.sub(inat, " ") : mo
      norm(residual.gsub(REGENERABLE, " ").gsub(/[;|]+/, " "))
    end

    # Non-importer note keys and values - the clean, recoverable delta that
    # moves to the native sibling on migration.
    def extra_note_keys(obs)
      notes = obs.notes
      return {} if notes.blank?

      notes.to_h.
        reject { |key, _| IMPORTER_NOTE_KEYS.include?(key.to_s) }.
        transform_keys(&:to_s)
    end

    def snapshot_field(text, label)
      match = text[/^#{Regexp.escape(label)}:\s*(.+)$/, 1]
      match&.strip.presence
    end
  end
end
