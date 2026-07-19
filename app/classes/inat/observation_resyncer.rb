# frozen_string_literal: true

require "json"

class Inat
  # Refreshes a read-only reflection observation (#4214) from its current
  # iNaturalist data (#4215). The scalar core (date / location / GPS /
  # notes) is MO's mirror of the source, so re-fetch it and update in
  # place. Only the source-owned fields are touched here; namings, votes,
  # comments, images and sequences are handled by later slices.
  #
  # Runs BELOW the read-only edit guard: that guard blocks the web/API
  # edit actions, while this service writes the record directly, so it can
  # refresh a reflection the user is (deliberately) not allowed to edit.
  #
  # Fetching is public and deletion-aware via `Inat::ObsFetcher`:
  #   - fetch failed (transient)  -> :fetch_failed, nothing touched;
  #   - id absent from results    -> :source_deleted, MO data kept, logged;
  #   - id present                -> :synced / :unchanged.
  class ObservationResyncer
    # status is one of :synced, :unchanged, :source_deleted, :fetch_failed,
    # :not_a_reflection.
    Result = Data.define(:status, :observation)

    def initialize(observation, fetcher: ObsFetcher.new)
      @observation = observation
      @fetcher = fetcher
    end

    def resync
      return result(:not_a_reflection) unless resyncable?

      by_id, failed = @fetcher.fetch_batch([inat_id])
      return result(:fetch_failed) if failed

      raw = by_id[inat_id.to_s]
      raw ? apply(Inat::Obs.new(JSON.generate(raw))) : handle_deleted
    end

    private

    # Only read-only iNat reflections are refreshable: the backlog of
    # still-editable imports (reflected_at nil) is left alone so a resync
    # can't clobber MO-side edits.
    def resyncable?
      @observation.reflection? && inat_import_link.present?
    end

    def inat_import_link
      link = @observation.import_link
      return nil unless link&.external_site&.name ==
                        ExternalSite::INATURALIST_NAME

      link
    end

    def inat_id
      inat_import_link.external_id
    end

    # Detect a REAL change from what persists, not from the assigned
    # values: setting `location` triggers a callback that rewrites `where`
    # to the location's name, so an in-memory `changed?` never converges.
    # `saved_changes` (sans the timestamp) reflects what actually moved.
    def apply(inat_obs)
      @observation.assign_attributes(scalar_attributes(inat_obs))
      @observation.save! if @observation.changed?
      changed = @observation.saved_changes.except("updated_at").present?
      mark_synced
      log_resync if changed
      result(changed ? :synced : :unchanged)
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

    # The iNat obs is gone: keep every MO record intact, record the loss on
    # the activity log, and still stamp last_synced_at so the check ran.
    def handle_deleted
      mark_synced
      @observation.log(:log_observation_source_deleted,
                       user: @observation.user)
      result(:source_deleted)
    end

    def mark_synced
      inat_import_link.update!(last_synced_at: Time.zone.now)
    end

    def log_resync
      @observation.log(:log_observation_resynced, user: @observation.user)
    end

    def result(status)
      Result.new(status: status, observation: @observation)
    end
  end
end
