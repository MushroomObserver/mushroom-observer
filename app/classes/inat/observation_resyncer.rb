# frozen_string_literal: true

require "json"

class Inat
  # Refreshes every read-only reflection (#4214) in an observation's
  # occurrence from its current iNaturalist data (#4215). Sync is an
  # occurrence-wide event: pressing "Sync now" on any member observation
  # refreshes all of the occurrence's reflections at essentially the same
  # time, in ONE rate-limited API call (`Inat::ObsFetcher#fetch_batch`
  # takes the whole id list). Each reflection's scalar core (date /
  # location / GPS / notes) is MO's mirror of its source, so it is
  # re-fetched and updated in place. Only source-owned fields are touched;
  # namings, votes, comments, images and sequences are handled by later
  # slices.
  #
  # Runs BELOW the read-only edit guard: that guard blocks the web/API
  # edit actions, while this service writes the records directly, so it
  # can refresh reflections nobody is allowed to hand-edit.
  #
  # Fetching is public and deletion-aware via `Inat::ObsFetcher`:
  #   - fetch failed (transient)  -> :fetch_failed, nothing touched;
  #   - id absent from results    -> :source_deleted, MO data kept, logged;
  #   - id present                -> :synced / :unchanged.
  class ObservationResyncer
    # Per-reflection outcome; status is one of :synced, :unchanged,
    # :source_deleted, :fetch_failed.
    Result = Data.define(:status, :observation)

    def initialize(observation, fetcher: ObsFetcher.new)
      @observation = observation
      @fetcher = fetcher
    end

    # Returns the Array of per-reflection Results (empty when the
    # occurrence has nothing to sync).
    def resync
      return [] if targets.empty?

      by_id, failed = @fetcher.fetch_batch(targets.map { |t| inat_id(t) })
      results = targets.map { |target| target_result(target, by_id, failed) }
      broadcast(results)
      results
    end

    private

    def target_result(target, by_id, failed)
      return Result.new(status: :fetch_failed, observation: target) if failed

      raw = by_id[inat_id(target).to_s]
      raw ? apply(target, Inat::Obs.new(JSON.generate(raw))) : deleted(target)
    end

    # The occurrence's reflections that have an iNat import link. Only
    # read-only reflections are refreshable: the backlog of still-editable
    # imports (reflected_at nil) is left alone so a resync can't clobber
    # MO-side edits.
    def targets
      @targets ||= @observation.sync_reflections.
                   select { |obs| inat_link(obs) }
    end

    def inat_link(obs)
      link = obs.import_link
      return nil unless link&.external_site&.name ==
                        ExternalSite::INATURALIST_NAME

      link
    end

    def inat_id(obs)
      inat_link(obs).external_id
    end

    # Check saved_changes, not changed?, to detect an update. Setting
    # `location` triggers a callback that rewrites `where` to match the
    # location's name. So `changed?` stays true even with no update.
    # Read `saved_changes` (minus the timestamp) to see what got saved.
    #
    # Save scalar attributes first. sync_placeholder_naming?'s consensus
    # recalculation does its own separate save, only when the consensus
    # itself changes -- so track each save's own "did it change" signal
    # instead of reading saved_changes once at the end.
    def apply(obs, inat_obs)
      if upgrade_eligible?(obs, inat_obs)
        return upgrade_placeholder(obs, inat_obs)
      end

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

    def upgrade_eligible?(obs, inat_obs)
      return false unless obs.placeholder?

      inat_obs[:license_code].present? || importer_is_collector?(obs, inat_obs)
    end

    # Is the MO importer the iNat collector?
    def importer_is_collector?(obs, inat_obs)
      obs.user.inat_username.present? &&
        obs.user.inat_username == inat_obs.collector
    end

    # Rebuild the placeholder as a full import, in the same row.
    # Change only the row's own columns and Namings.
    # Keep the id, Comments, and Occurrence.
    #
    # When the importer is the iNat collector, treat this as their own
    # import: set import_others: false. Then unlicensed photos import
    # too, same as any import of a user's own observation.
    # Else, when only the now-licensed trigger fired, keep import_others
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

    # The source-owned scalar fields, from the fresh iNat data.
    # `where` is set only if no Location resolves: a present Location
    # drives `where` from its own name via a callback, so assigning
    # `where` too would flip it back and forth and never converge.
    #
    # A placeholder gets a narrower sync than a normal reflection;
    # only date/location change here.
    # `notes` is excluded -- a placeholder includes a fixed message
    # instead of the iNat source's Notes/description. So a resync must not
    # change that. `specimen` is left alone too.
    #
    # The leading ID has its own handling in sync_placeholder_naming? below.
    def scalar_attributes(obs, inat_obs)
      location = inat_obs.location
      attrs = { when: inat_obs.when, location: location, lat: inat_obs.lat,
                lng: inat_obs.lng, gps_hidden: inat_obs.gps_hidden }
      attrs[:where] = inat_obs.where if location.nil?
      return attrs if obs.placeholder?

      attrs.merge(specimen: inat_obs.specimen?, notes: inat_obs.notes)
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

    # Revise the stand-in Naming in place while it's still unlocked; fork
    # a new one instead once an outside vote has locked it.
    def revise_or_fork_naming(stand_in, lead_name, resolver, consensus,
                              inat_obs)
      if consensus.editable?(stand_in)
        stand_in.update!(name: lead_name,
                         reasons: { 2 => resolver.reason_text })
      else
        fork_stand_in_naming(consensus, lead_name, resolver, inat_obs)
        consensus.mark_obs_reviewed(consensus.observation.user)
      end
    end

    # New stand-in Naming -- same shape as
    # SkeletonObservationBuilder#add_naming_with_vote.
    def fork_stand_in_naming(consensus, name, resolver, inat_obs)
      obs = consensus.observation
      naming = Naming.create(
        observation: obs, user: obs.user, name: name,
        reasons: { 2 => resolver.reason_text }
      )
      Vote.create(naming: naming, observation: obs, user: obs.user,
                  value: placeholder_naming_vote(inat_obs))
      obs.update!(inat_stand_in_naming_id: naming.id)
    end

    # Same confidence weight SkeletonObservationBuilder#naming_vote uses.
    def placeholder_naming_vote(inat_obs)
      if inat_obs[:quality_grade] == "research"
        Vote::NEXT_BEST_VOTE
      else
        Vote::MIN_POS_VOTE
      end
    end

    # The iNat obs is gone: keep every MO record intact, record the loss on
    # the activity log, and still stamp last_synced_at so the check ran.
    def deleted(obs)
      mark_synced(obs)
      obs.log(:log_observation_source_deleted, user: User.admin)
      Result.new(status: :source_deleted, observation: obs)
    end

    def mark_synced(obs)
      inat_link(obs).update!(last_synced_at: Time.zone.now)
    end

    # Sync is owned by the admin account: anyone logged in may trigger
    # it, and the scheduled batch has no triggering user at all, so the
    # log attributes every resync to the system actor rather than to
    # whoever happened to press the button.
    def log_resync(obs)
      obs.log(:log_observation_resynced, user: User.admin)
    end

    # Turbo Stream broadcast so "Sync now" updates pages live, no reload
    # (#4215) -- see Observations::InatResyncsController#create for why
    # the controller response itself is flash-only. The aggregate flash
    # goes to EVERY member observation's channel (a viewer may be on the
    # primary's page, not a reflection's); panel updates go to each
    # changed reflection's own channel, since the DOM targets are that
    # page's panels. Rendering uses no user -- the channel is shared by
    # every viewer of the page, so the safe logged-out-equivalent view is
    # the only one that's right for all of them.
    def broadcast(results)
      flash_html = render_flash(results)
      members.each do |member|
        Turbo::StreamsChannel.broadcast_update_to(
          channel(member), target: "page_flash", html: flash_html
        )
      end
      results.select { |r| r.status == :synced }.
        each { |r| broadcast_panels(r.observation) }
    end

    def members
      occ = @observation.occurrence
      occ ? occ.observations.to_a : [@observation]
    end

    def channel(obs)
      [obs, :external_link_sync]
    end

    # One aggregate message for the whole occurrence: refreshed count,
    # missing-source count (called out explicitly -- the owner should
    # notice), or a plain up-to-date/failed line. The worst outcome
    # drives the alert level. MessageAlert (not a bare Components::
    # Alert) -- see .claude/rules/phlex_reference.md's "Rendering Phlex
    # outside a request".
    def render_flash(results)
      level, message = flash_level_and_message(results)
      ApplicationController.renderer.render(
        Views::Layouts::App::MessageAlert.new(message: message, level: level),
        layout: false
      )
    end

    def flash_level_and_message(results)
      counts = results.group_by(&:status).transform_values(&:count)
      return [:danger, :observation_resync_failed.t] if counts[:fetch_failed]

      parts = flash_parts(counts)
      return [:success, :observation_resync_unchanged.t] if parts.empty?

      [counts[:source_deleted] ? :warning : :success, parts.safe_join(" ")]
    end

    def flash_parts(counts)
      parts = []
      if (synced = counts[:synced])
        parts << :observation_resync_synced.t(count: synced)
      end
      if (deleted = counts[:source_deleted])
        parts << :observation_resync_source_deleted.t(count: deleted)
      end
      parts
    end

    # Only `:synced` changes anything these panels display (when /
    # location / GPS / notes / leading ID for a placeholder, #4828) --
    # `:unchanged`/`:source_deleted`/`:fetch_failed` leave the
    # observation's own data untouched, so there's nothing to re-render
    # there.
    #
    # Deliberately NOT broadcasting the Proposed Name table
    # (Views::Controllers::Observations::Show::Namings) or the page's own
    # title here, even though a placeholder resync can revise the
    # leading-ID Naming: Namings' row/footer sub-views require a real,
    # non-nilable @user for permission-gated vote/edit/propose buttons,
    # and this broadcast is rendered once for a channel shared by every
    # viewer, with no per-viewer user available (the resync itself runs
    # in a background job, InatObservationResyncJob, off the requesting
    # user's session entirely). Reflecting that fully live would mean
    # reworking Namings to tolerate user: nil, or adding a separate
    # read-only display -- out of scope here; a page reload shows the
    # revised name. NameInfoPanel ("About this taxon") is safe to
    # broadcast because its own `user` prop is already nilable.
    def broadcast_panels(observation)
      broadcast_replace(observation, "observation_details",
                        Views::Controllers::Observations::Show::Details.new(
                          obs: observation, user: nil,
                          sites: addable_sites(observation),
                          siblings: siblings_of(observation)
                        ))
      broadcast_replace(observation, "observation_notes",
                        Views::Controllers::Observations::Show::NotesPanel.new(
                          obs: observation, user: nil
                        ))
      broadcast_replace(
        observation, "observation_name_info",
        Views::Controllers::Observations::Show::NameInfoPanel.new(
          obs: observation, user: nil
        )
      )
    end

    # Same lookup `Observations::ExternalLinksController::Show` uses for
    # the same panel's own turbo-stream re-render -- which external
    # sites the viewer may still add a link to (none for the no-user
    # rendering, matching the logged-out view).
    def addable_sites(observation)
      ExternalSite.sites_user_can_add_links_to_for_obs(nil, observation).
        to_a
    end

    def siblings_of(observation)
      return [] unless observation.occurrence

      observation.occurrence.observations.where.not(id: observation.id).
        includes(:external_links).to_a
    end

    def broadcast_replace(observation, target, component)
      Turbo::StreamsChannel.broadcast_replace_to(
        channel(observation), target: target,
                              html: ApplicationController.renderer.render(
                                component, layout: false
                              )
      )
    end
  end
end
