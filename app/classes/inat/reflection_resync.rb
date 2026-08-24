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
    #   id absent from results    -> :source_deleted, MO data kept, logged;
    #   id present                -> :synced / :unchanged.
    def call(reflection, by_id, failed)
      return failed_result(reflection) if failed

      raw = by_id[self.class.inat_id(reflection).to_s]
      return deleted(reflection) unless raw

      apply(reflection, Inat::Obs.new(JSON.generate(raw)))
    end

    private

    def failed_result(reflection)
      Result.new(status: :fetch_failed, observation: reflection)
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

    def mark_synced(obs)
      self.class.inat_link(obs).update!(last_synced_at: Time.zone.now)
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
    def scalar_attributes(inat_obs)
      location = inat_obs.location
      attrs = { when: inat_obs.when, location: location, lat: inat_obs.lat,
                lng: inat_obs.lng, gps_hidden: inat_obs.gps_hidden,
                specimen: inat_obs.specimen?, notes: inat_obs.notes }
      attrs[:where] = inat_obs.where if location.nil?
      attrs
    end
  end
end
