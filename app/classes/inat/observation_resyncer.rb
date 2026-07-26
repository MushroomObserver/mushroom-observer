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

    # Detect a REAL change from what persists, not from the assigned
    # values: setting `location` triggers a callback that rewrites `where`
    # to the location's name, so an in-memory `changed?` never converges.
    # `saved_changes` (sans the timestamp) reflects what actually moved.
    def apply(obs, inat_obs)
      obs.assign_attributes(scalar_attributes(obs, inat_obs))
      obs.save! if obs.changed?
      changed = obs.saved_changes.except("updated_at").present?
      mark_synced(obs)
      log_resync(obs) if changed
      Result.new(status: changed ? :synced : :unchanged, observation: obs)
    end

    # The source-owned scalar fields, straight off the fresh iNat data.
    # `where` is only set when no Location resolves: a present Location
    # drives `where` from its own name via a callback, so assigning
    # `where` too would flip it back and forth and never converge.
    def scalar_attributes(_obs, inat_obs)
      location = inat_obs.location
      attrs = { when: inat_obs.when, location: location, lat: inat_obs.lat,
                lng: inat_obs.lng, gps_hidden: inat_obs.gps_hidden,
                specimen: inat_obs.specimen?, notes: inat_obs.notes }
      attrs[:where] = inat_obs.where if location.nil?
      attrs
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
    # location / GPS / notes) -- `:unchanged`/`:source_deleted`/
    # `:fetch_failed` leave the observation's own data untouched, so
    # there's nothing to re-render there.
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
