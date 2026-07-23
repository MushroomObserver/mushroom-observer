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

    FLASH_BY_STATUS = {
      synced: [:success, :observation_resync_synced],
      unchanged: [:success, :observation_resync_unchanged],
      source_deleted: [:warning, :observation_resync_source_deleted],
      fetch_failed: [:danger, :observation_resync_failed]
    }.freeze

    # `user:` is the viewer who triggered the resync (nil for a future
    # batch job with no single triggering viewer) -- used only to render
    # the completion broadcast's panel updates from that viewer's
    # permissions (which external sites they may still add a link to).
    def initialize(observation, user: nil, fetcher: ObsFetcher.new)
      @observation = observation
      @user = user
      @fetcher = fetcher
    end

    def resync
      return result(:not_a_reflection) unless resyncable?

      by_id, failed = @fetcher.fetch_batch([inat_id])
      return broadcast(result(:fetch_failed)) if failed

      raw = by_id[inat_id.to_s]
      broadcast(raw ? apply(Inat::Obs.new(JSON.generate(raw))) : handle_deleted)
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

    # Turbo Stream broadcast so "Sync now" updates the page live, no
    # reload (#4215) -- see Observations::InatResyncsController#create
    # for why the controller response itself is flash-only. Channel is
    # scoped to the observation (not a user, unlike InatImport's own
    # broadcast) since anyone viewing the observation's page should see
    # the same result -- rendered from the triggering @user's own
    # permissions (nil, the safe logged-out-equivalent view, when there
    # isn't one), same simplification `InatImport`'s per-user channel
    # sidesteps by only ever having one relevant viewer (the importer).
    def broadcast(result)
      channel = [result.observation, :external_link_sync]
      Turbo::StreamsChannel.broadcast_update_to(
        channel, target: "page_flash", html: render_flash(result.status)
      )
      broadcast_panels(channel, result.observation) if result.status == :synced
      result
    end

    # MessageAlert (not a bare Components::Alert) -- see
    # .claude/rules/phlex_reference.md's "Rendering Phlex outside a
    # request": a block passed to ApplicationController.renderer.render
    # never reaches the component, so Alert's trusted block form can't
    # be used directly here, and Alert#message always escapes via
    # plain() (MO's translations store HTML entities literally, e.g. a
    # typographic apostrophe as &#8217;, so plain() would double-escape
    # them).
    def render_flash(status)
      level, tag = FLASH_BY_STATUS.fetch(status)
      ApplicationController.renderer.render(
        Views::Layouts::App::MessageAlert.new(message: tag.t, level: level),
        layout: false
      )
    end

    # Only `:synced` changes anything these panels display (when /
    # location / GPS / notes) -- `:unchanged`/`:source_deleted`/
    # `:fetch_failed` leave the observation's own data untouched, so
    # there's nothing to re-render there.
    def broadcast_panels(channel, observation)
      broadcast_replace(channel, "observation_details",
                        Views::Controllers::Observations::Show::Details.new(
                          obs: observation, user: @user,
                          sites: addable_sites(observation),
                          siblings: siblings_of(observation)
                        ))
      broadcast_replace(channel, "observation_notes",
                        Views::Controllers::Observations::Show::NotesPanel.new(
                          obs: observation, user: @user
                        ))
    end

    # Same lookup `Observations::ExternalLinksController::Show` uses for
    # the same panel's own turbo-stream re-render -- which external
    # sites the viewer may still add a link to.
    def addable_sites(observation)
      ExternalSite.sites_user_can_add_links_to_for_obs(@user, observation).
        to_a
    end

    def siblings_of(observation)
      return [] unless observation.occurrence

      observation.occurrence.observations.where.not(id: observation.id).
        includes(:external_links)
    end

    def broadcast_replace(channel, target, component)
      Turbo::StreamsChannel.broadcast_replace_to(
        channel, target: target,
                 html: ApplicationController.renderer.render(component,
                                                             layout: false)
      )
    end
  end
end
