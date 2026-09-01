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
  # A placeholder (skeleton) gets narrower scalar treatment (no
  # notes) and Naming/consensus handling and can upgrade to a full import
  # outright; see #upgrade_eligible?.
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
    # in-memory `changed?` doesn't converge. `saved_changes` (sans the
    # timestamp) reflects what persisted.
    #
    # A placeholder eligible to become a full import (#4828) skips the
    # narrow scalar sync below entirely -- see upgrade_eligible?.
    def apply(obs, inat_obs)
      return upgrade_placeholder(obs, inat_obs) if upgrade_eligible?(obs,
                                                                     inat_obs)

      obs.assign_attributes(scalar_attributes(obs, inat_obs))
      obs.save! if obs.changed?
      scalar_changed = obs.saved_changes.except("updated_at").present?

      naming_changed = obs.placeholder? &&
                       sync_placeholder_naming?(obs, inat_obs)
      changed = scalar_changed || naming_changed

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
    # the button, and the scheduled batch has no triggering user, so
    # every resync is attributed to the system actor.
    def log_resync(obs)
      obs.log(:log_observation_resynced, user: User.admin)
    end

    # Fields from the fresh iNat data.
    # Date and the obscured flag always mirror the source;
    # specimen is MO-owned and left alone.
    # Coordinates sync only if iNat is NOT obscuring the location --
    # an obscured observation yields only iNat's blurred public coordinate,
    # which would overwrite the authenticated import's accurate one.
    #
    # A placeholder gets narrower treatment:
    # a placeholder holds a fixed message instead of the iNat Notes/description
    # A resync must not overwrite that with the source's notes.
    def scalar_attributes(obs, inat_obs)
      attrs = { when: inat_obs.when, gps_hidden: inat_obs.obscured? }
      attrs[:notes] = inat_obs.notes unless obs.placeholder?
      attrs.merge!(location_attributes(inat_obs)) unless inat_obs.obscured?
      attrs
    end

    # A present Location drives `where` from the Location's name via a
    # callback, so `where` is set only when no Location resolves
    # (otherwise the two flip back and forth without settling).
    def location_attributes(inat_obs)
      location = inat_obs.location
      attrs = { location: location, lat: inat_obs.lat, lng: inat_obs.lng }
      attrs[:where] = inat_obs.where if location.nil?
      attrs
    end

    # A placeholder is eligible to upgrade to a full import once
    # MO may import the whole record: the iNat obs is now
    # licensed, or the importer turns out to be the iNat observer.
    def upgrade_eligible?(obs, inat_obs)
      return false unless obs.placeholder?

      inat_obs[:license_code].present? ||
        importer_is_collector?(obs, inat_obs)
    end

    # Is the MO importer the iNat observer?
    # Compares to the account's login, not #collector -- a
    # custom Collector observation field can name someone who does
    # not the iNat observer.
    def importer_is_collector?(obs, inat_obs)
      obs.user.inat_username.present? &&
        obs.user.inat_username.casecmp?(inat_obs[:user][:login].to_s)
    end

    # Rebuild the placeholder as a full import, in the same row.
    # Change only the row's columns and Namings.
    # Keep the id, Comments, and Occurrence.
    #
    # When the importer is the iNat collector, set import_others: false,
    # as for a direct import -- unlicensed photos then import too. Else,
    # when only the now-licensed trigger fired, keep import_others true.
    # Per-photo license checks then decide each photo separately.
    #
    # Don't suppress notifications. A batch import has a digest to
    # catch them. A lone sync doesn't.
    def upgrade_placeholder(obs, inat_obs)
      Inat::MoObservationBuilder.new(
        inat_obs: inat_obs, user: obs.user, observation: obs,
        import_others: !importer_is_collector?(obs, inat_obs)
      ).mo_observation
      mark_synced(obs)
      Result.new(status: :synced, observation: obs)
    end

    # Revise MO's stand-in Naming if iNat's Leading ID changes and
    # it's unlocked (no outside vote). Once locked, fork a new stand-in
    # instead of touching the old one. Find the stand-in by
    # obs.inat_stand_in_naming_id.
    #
    # Recalculate consensus on a change, so votes -- not iNat -- decide
    # the observation's displayed name.
    def sync_placeholder_naming?(obs, inat_obs)
      resolver = Inat::LeadNameResolver.new(inat_obs: inat_obs, user: obs.user)
      lead_name = resolver.leading_id_name
      consensus = Observation::NamingConsensus.new(obs)
      stand_in = stand_in_naming(obs)
      return false unless stand_in
      return false if lead_name == stand_in.name

      revise_or_fork_naming(stand_in, lead_name, resolver, consensus,
                            inat_obs)
      consensus.calc_consensus(User.admin)
      obs.reload
      true
    end

    def stand_in_naming(obs)
      return nil unless obs.inat_stand_in_naming_id

      Naming.find_by(id: obs.inat_stand_in_naming_id)
    end

    # Revise the stand-in Naming in place while it's still unlocked --
    # unless the importer already has a different Naming for the same
    # lead name, which revising in place would collide with (namings has
    # a unique index on observation/user/name, #5186). Either way, fork
    # instead when that's blocked.
    def revise_or_fork_naming(stand_in, lead_name, resolver, consensus,
                              inat_obs)
      if consensus.editable?(stand_in) &&
         !other_naming_for?(stand_in, lead_name)
        stand_in.update!(name: lead_name,
                         reasons: { 2 => resolver.reason_text })
      else
        fork_stand_in_naming(consensus, lead_name, resolver, inat_obs)
      end
    end

    def other_naming_for?(stand_in, lead_name)
      stand_in.observation.namings.where(user: stand_in.user, name: lead_name).
        where.not(id: stand_in.id).exists?
    end

    # New stand-in Naming for the Leading ID -- reusing the importer's
    # existing Naming for that name when they already have one (same
    # unique-index reasoning as MoObservationBuilder#add_naming_with_vote)
    # instead of colliding with it. Otherwise the same shape as
    # SkeletonObservationBuilder#add_naming_with_vote.
    def fork_stand_in_naming(consensus, name, resolver, inat_obs)
      obs = consensus.observation
      naming = obs.namings.find_by(user: obs.user, name: name) ||
               Naming.create!(
                 observation: obs, user: obs.user, name: name,
                 reasons: { 2 => resolver.reason_text }
               )
      Vote.find_or_initialize_by(naming: naming, user: obs.user).
        update!(observation: obs, value: placeholder_naming_vote(inat_obs))
      obs.update!(inat_stand_in_naming_id: naming.id)
      consensus.mark_obs_reviewed(obs.user)
    end

    # Same confidence weight SkeletonObservationBuilder#naming_vote uses.
    def placeholder_naming_vote(inat_obs)
      if inat_obs[:quality_grade] == "research"
        Vote::NEXT_BEST_VOTE
      else
        Vote::MIN_POS_VOTE
      end
    end
  end
end
