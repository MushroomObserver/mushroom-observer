# frozen_string_literal: true

require "json"

class Inat
  # Refreshes every read-only reflection (#4214) in an observation's
  # occurrence from its current iNaturalist data (#4215). Sync is an
  # occurrence-wide event: pressing "Sync now" on any member observation
  # refreshes all of the occurrence's reflections at essentially the same
  # time, in ONE rate-limited API call (`Inat::ObsFetcher#fetch_batch`
  # takes the whole id list). Each reflection's scalar core, sequences,
  # source-derived namings and images mirror its source and are updated
  # in place; MO-side records (comments, people's namings and votes) are
  # left alone.
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

    # Engine messages from this occurrence's resyncs (ambiguous locus
    # pairings, iNat values MO can't resolve, photos that failed to
    # import). InatObservationResyncJob routes them to #alerts, the same
    # as the scheduled batch does -- a "Sync now" that declines to act
    # needs a human either way, and the flash can't say so: it is one
    # aggregate line for the whole occurrence, shown to whoever pressed
    # the button rather than to whoever can act on it.
    delegate :alerts, to: :@applier

    def initialize(observation, fetcher: ObsFetcher.new,
                   applier: ReflectionResync.new)
      @observation = observation
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
      results = targets.map { |target| @applier.call(target, by_id, failed) }
      broadcast(results)
      results
    end

    private

    # The occurrence's reflections that have an iNat import link. Only
    # read-only reflections are refreshable: the backlog of still-editable
    # imports (reflected_at nil) is left alone so a resync can't clobber
    # MO-side edits.
    def targets
      @targets ||= @observation.sync_reflections.
                   select { |obs| ReflectionResync.inat_link(obs) }
    end

    # Turbo Stream broadcast so "Sync now" updates pages live (#4215) --
    # see Observations::InatResyncsController#create for why the
    # controller response itself is flash-only. The aggregate flash goes
    # to EVERY member observation's channel (a viewer may be on the
    # primary's page, not a reflection's). A changed reflection's page
    # refreshes instead of taking rendered panels: the namings panel and
    # title are per-viewer, and the channel is shared by every viewer,
    # so each browser refetches its page with its session. The
    # `refresh_with_flash` action (app/javascript/application.js) carries
    # the flash across that refetch.
    def broadcast(results)
      flash_html = render_flash(results)
      last_synced_html = render_last_synced(results)
      changed_ids = results.select { |r| r.status == :synced }.
                    map { |r| r.observation.id }
      members.each do |member|
        if changed_ids.include?(member.id)
          broadcast_action(member, :refresh_with_flash, html: flash_html)
        else
          broadcast_action(member, :update, target: "page_flash",
                                            html: flash_html)
          broadcast_last_synced(member, last_synced_html)
        end
      end
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

    # Nothing is stamped when the fetch failed, so there is no newer time
    # to show.
    def render_last_synced(results)
      return if results.any? { |r| r.status == :fetch_failed }

      ApplicationController.renderer.render(
        Views::Controllers::Observations::ExternalLinks::LastSynced.new(
          synced_at: @observation.last_synced_at
        ),
        layout: false
      )
    end

    def broadcast_last_synced(member, html)
      return unless html

      broadcast_action(member, :replace, targets: ".reflection-last-synced",
                                         html: html)
    end

    def broadcast_action(member, action, **)
      Turbo::StreamsChannel.broadcast_action_to(channel(member),
                                                action: action, **)
    end
  end
end
