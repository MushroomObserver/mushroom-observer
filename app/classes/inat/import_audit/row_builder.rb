# frozen_string_literal: true

module Inat::ImportAudit
  # Builds one audit row per imported observation, oriented around the
  # migration question: what MO-side data would a reimport-overwrite drop,
  # and is that delta clean (recoverable to a sibling) or ambiguous?
  # See doc/inat_import_migration_strategy.md.
  class RowBuilder
    include Compare

    def initialize(source:)
      @source = source
    end

    def call(obs, raw, fetch_failed: false)
      inat = raw ? Inat::Obs.new(JSON.generate(raw)) : nil
      snapshot = obs_snapshot(obs).to_s
      status = inat_status(raw, fetch_failed)
      notes = notes_delta_columns(obs, inat)
      collector = collector_columns(obs, snapshot)
      images = image_columns(obs, raw)
      base_columns(obs, snapshot, status).
        merge(notes).merge(collector).merge(images).
        merge(flag_columns(raw, snapshot, notes, collector, images))
    end

    private

    def base_columns(obs, snapshot, status)
      {
        mo_id: obs.id,
        mo_url: "#{MO.http_domain}/#{obs.id}",
        inat_id: obs.external_id,
        inat_url: @source.observation_url(obs.external_id),
        inat_status: status,
        snapshot_present: snapshot.present?
      }.merge(timestamp_columns(obs))
    end

    def timestamp_columns(obs)
      {
        created_at: obs.created_at&.iso8601,
        updated_at: obs.updated_at&.iso8601,
        last_log_at: obs.rss_log&.updated_at&.iso8601
      }
    end

    def inat_status(raw, fetch_failed)
      return "ok" if raw
      return "fetch_error" if fetch_failed

      "not_found"
    end

    # --- Notes delta ---

    def notes_delta_columns(obs, inat)
      extra = extra_note_keys(obs)
      residual = inat &&
                 other_residual(obs.other_notes, inat.cleaned_description)
      {
        delta_note_keys: extra.keys.join("|"),
        delta_note_count: extra.size,
        delta_notes_json: extra.empty? ? nil : JSON.generate(extra),
        other_residual: residual.presence
      }
    end

    # --- Collector / identity ---

    def collector_columns(obs, snapshot)
      uploader = snapshot_field(snapshot, :USER.l)
      {
        collector: obs.collector,
        collector_user_login: obs.collector_user&.login,
        inat_uploader: uploader,
        collector_differs: collector_differs?(obs, uploader)
      }
    end

    # True when the recorded collector is a DIFFERENT person than the iNat
    # uploader - not merely a different username for the same person. Compares
    # against the MO user the uploader's iNat login maps to (via inat_username).
    def collector_differs?(obs, uploader)
      return false if uploader.blank?

      mapped = uploader_user(uploader)
      if obs.collector_user_id
        # Only a confirmed different MO user counts; an unmapped uploader
        # (no inat_username) is "can't confirm", not a divergence.
        mapped ? obs.collector_user_id != mapped.id : false
      elsif obs.collector.present?
        !collector_names_uploader?(obs.collector, uploader, mapped)
      else
        false
      end
    end

    def collector_names_uploader?(collector, uploader, mapped)
      [uploader, mapped&.login, mapped&.name].compact.
        any? { |name| norm(name).casecmp(norm(collector)).zero? }
    end

    def uploader_user(uploader)
      (@uploader_users ||= {}).fetch(uploader) do
        @uploader_users[uploader] = User.find_by(inat_username: uploader)
      end
    end

    # --- Images ---

    # No images_modified: an updated_at gap isn't evidence of a pixel edit
    # (rows are touched for votes/views/reprocessing), and rotation is
    # destructive with no metadata - we can't reliably detect edits.
    def image_columns(obs, raw)
      mo = obs.images.size
      inat = raw ? (raw[:observation_photos]&.size || 0) : nil
      {
        images_mo: mo,
        images_inat: inat,
        images_count_match: inat.nil? ? nil : (mo == inat)
      }
    end

    # --- Flags ---

    # ambiguous: delta can't be cleanly separated (mixed :Other, image-count
    # mismatch, or no snapshot baseline). has_delta: any MO-side data a
    # reimport-overwrite would drop.
    def flag_columns(raw, snapshot, notes, collector, images)
      ambiguous = notes[:other_residual].present? ||
                  images[:images_count_match] == false ||
                  (raw && snapshot.blank?)
      has_delta = notes[:delta_note_count].positive? ||
                  notes[:other_residual].present? ||
                  collector[:collector_differs]
      { has_delta: has_delta, ambiguous: ambiguous }
    end

    # The import snapshot lives in notes[:iNat_imported_data], or - for the
    # early importer - in a "Snapshot of Imported iNat Data" comment.
    def obs_snapshot(obs)
      notes = obs.notes
      return notes[:iNat_imported_data] if notes.present? &&
                                           notes[:iNat_imported_data].present?

      Comment.where(target_type: "Observation", target_id: obs.id).
        where("summary LIKE ?", "Snapshot of Imported iNat Data%").
        pick(:comment)
    end
  end
end
