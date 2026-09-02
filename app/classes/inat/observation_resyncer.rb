# frozen_string_literal: true

require "json"

class Inat
  # Refreshes every read-only reflection in an observation's
  # occurrence from its current iNat data. Sync is an
  # occurrence-wide event: pressing "Sync now" on any member observation
  # refreshes all of the occurrence's reflections at essentially the same
  # time, in ONE rate-limited API call (`Inat::ObsFetcher#fetch_batch`
  # takes the whole id list). Each reflection's scalar core (date /
  # location / GPS / notes) is MO's mirror of its source, so it is
  # re-fetched and updated in place. Only source-owned fields are touched;
  # namings, votes, comments, images and sequences are handled by later
  # slices.
  #
  # The per-reflection refresh itself lives in Inat::ReflectionResync,
  # shared with the scheduled daily batch (Inat::ReflectionBatchResyncer);
  # this class adds the occurrence-wide framing and the Turbo broadcast
  # that updates the page live.
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
    # Per-reflection outcomes come from Inat::ReflectionResync; re-exported
    # here for callers and tests that reference the occurrence path.
    Result = ReflectionResync::Result

    # `user:` is the person who clicked "Sync now", when known -- absent
    # for the scheduled daily batch.
    def initialize(observation, user: nil, fetcher: ObsFetcher.new,
                   applier: ReflectionResync.new)
      @observation = observation
      @user = user
      @fetcher = fetcher
      @applier = applier
    end

    # Returns the Array of per-reflection Results (empty when the
    # occurrence has nothing to sync).
    def resync
      return [] if targets.empty?

      by_id, failed = @fetcher.fetch_batch(
        targets.map { |t| ReflectionResync.inat_id(t) }
      )
      results = targets.map do |target|
        @applier.call(target, by_id, failed, user: @user)
      end
      broadcast(results)
      results
    end

    private

    # The occurrence's reflections that have an iNat import link.
    def targets
      @targets ||= @observation.sync_reflections.
                   select { |obs| ReflectionResync.inat_link(obs) }
    end

    # Turbo Stream broadcast so "Sync now" updates pages live
    # The controller response itself is flash-only. The aggregate flash
    # goes to EVERY member observation's channel; panel updates go to each
    # changed reflection's channel.
    # Rendering uses no user -- the channel is shared by
    # every viewer of the page.
    def broadcast(results)
      flash_html = render_flash(results)
      members.each do |member|
        Turbo::StreamsChannel.broadcast_update_to(
          channel(member), target: "page_flash", html: flash_html
        )
      end
      results.select { |r| r.status == :synced }.each do |r|
        broadcast_panels(r.observation)
        Turbo::StreamsChannel.broadcast_refresh_to(
          channel(r.observation),
          # request_id: nil, else Turbo's client-side dedup would skip
          # refreshing whichever client clicked "Sync now".
          request_id: nil
        )
      end
    end

    def members
      occ = @observation.occurrence
      occ ? occ.observations.to_a : [@observation]
    end

    def channel(obs)
      [obs, :external_link_sync]
    end

    # Aggregate message for the whole occurrence: refreshed count,
    # missing-source count, or a plain up-to-date/failed line.
    # The worst outcome drives the alert level.
    # MessageAlert (not a bare Components::Alert).
    # See .claude/rules/phlex_reference.md's "Rendering Phlex
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

    # Re-render Details, NotesPanel, NameInfoPanel with synced data.
    #
    # Skips the Proposed Name table and page title: they need a
    # per-viewer user for permission-gated buttons, but this broadcast
    # renders once, with no viewer, for a channel shared by every
    # subscriber. #broadcast's accompanying refresh stream covers those
    # two instead.
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
