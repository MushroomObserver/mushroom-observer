# frozen_string_literal: true

require "json"

class Inat
  # Applies one iNaturalist fetch result to one read-only reflection
  # (#4215): refreshes the source-owned scalar core (date / location /
  # GPS / notes), handles a source that was deleted on iNat, stamps
  # `last_synced_at`, and logs the outcome as the admin actor. This is
  # the per-reflection unit shared by both sync triggers -- the
  # occurrence-wide "Sync now" button (Inat::ObservationResyncer) and the
  # scheduled daily batch (Inat::ReflectionBatchResyncer) -- so the
  # fields touched and the logging stay identical no matter what started
  # the sync.
  #
  # Runs BELOW the read-only edit guard: that guard blocks the web/API
  # edit actions, while this writes the records directly, so it can
  # refresh reflections nobody is allowed to hand-edit.
  class ReflectionResync
    # Per-reflection outcome; status is one of :synced, :unchanged,
    # :source_deleted, :fetch_failed.
    Result = Data.define(:status, :observation)

    # The reflection's iNaturalist import link, or nil when it has none.
    def self.inat_link(reflection)
      link = reflection.import_link
      return nil unless link&.external_site&.name ==
                        ExternalSite::INATURALIST_NAME

      link
    end

    def self.inat_id(reflection)
      inat_link(reflection)&.external_id
    end

    # Turn one reflection plus the batch's (by_id, failed) into a Result.
    #   fetch failed (transient)  -> :fetch_failed, nothing touched;
    #   id present                -> :synced / :unchanged;
    #   id absent from results    -> depends on `absent:`.
    #
    # `absent:` is what a missing id means, which depends on how the
    # batch was fetched. A full fetch (the "Sync now" button) queried
    # every id, so a missing one is gone from iNat -> :deleted. An
    # incremental fetch (updated_since) returns only changed ids, so a
    # missing one merely didn't change -> :unchanged, untouched.
    def call(reflection, by_id, failed, absent: :deleted)
      return failed_result(reflection) if failed

      raw = by_id[self.class.inat_id(reflection).to_s]
      return apply(reflection, Inat::Obs.new(JSON.generate(raw))) if raw

      absent == :deleted ? deleted(reflection) : unchanged(reflection)
    end

    private

    def failed_result(reflection)
      Result.new(status: :fetch_failed, observation: reflection)
    end

    # Not in this incremental batch's results, so unchanged on iNat: leave
    # the reflection alone, don't even stamp -- it wasn't fetched.
    def unchanged(reflection)
      Result.new(status: :unchanged, observation: reflection)
    end

    # Detect a change from what persists, not from the assigned values:
    # setting `location` triggers a callback that rewrites `where`, so an
    # in-memory `changed?` never converges. `saved_changes` (sans the
    # timestamp) reflects what actually moved.
    def apply(obs, inat_obs)
      obs.assign_attributes(scalar_attributes(inat_obs))
      obs.save! if obs.changed?
      changed = obs.saved_changes.except("updated_at").present?
      mark_synced(obs)
      log_resync(obs) if changed
      Result.new(status: changed ? :synced : :unchanged, observation: obs)
    end

    # The iNat obs is gone: keep every MO record intact, record the loss
    # on the activity log, and still stamp last_synced_at so the check ran.
    def deleted(obs)
      mark_synced(obs)
      obs.log(:log_observation_source_deleted, user: User.admin)
      Result.new(status: :source_deleted, observation: obs)
    end

    # update_column, not update!, so stamping the sync time isn't blocked
    # by validating unrelated fields on the link (e.g. a pre-existing
    # invalid URL) and doesn't bump its updated_at.
    def mark_synced(obs)
      self.class.inat_link(obs).update_column(:last_synced_at, Time.zone.now)
    end

    # Sync is owned by the admin account: anyone logged in may trigger
    # the button, and the scheduled batch has no triggering user at all,
    # so every resync is attributed to the system actor.
    def log_resync(obs)
      obs.log(:log_observation_resynced, user: User.admin)
    end

    # The source-owned scalar fields, straight off the fresh iNat data.
    # `where` is only set when no Location resolves: a present Location
    # drives `where` from its own name via a callback, so assigning
    # `where` too would flip it back and forth and never converge.
    # Date, notes and the obscured flag always mirror the source; specimen
    # is MO-owned (see git history) and left alone. Coordinates sync only
    # when iNat is NOT obscuring the location -- the resync fetches iNat
    # unauthenticated (Inat::ApiToken is per-user; both the scheduled batch
    # and "Sync now" run as no user), so an obscured observation yields
    # only iNat's blurred public coordinate, which would overwrite the
    # authenticated import's accurate one. The first run degraded 1,421
    # reflections that way (#4215) before this gate was added.
    def scalar_attributes(inat_obs)
      attrs = { when: inat_obs.when, notes: inat_obs.notes,
                gps_hidden: inat_obs.obscured? }
      attrs.merge!(location_attributes(inat_obs)) unless inat_obs.obscured?
      attrs
    end

    # A present Location drives `where` from its own name via a callback,
    # so `where` is set only when no Location resolves (otherwise the two
    # flip back and forth without converging).
    def location_attributes(inat_obs)
      location = inat_obs.location
      attrs = { location: location, lat: inat_obs.lat, lng: inat_obs.lng }
      attrs[:where] = inat_obs.where if location.nil?
      attrs
    end
  end
end
