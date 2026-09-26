# frozen_string_literal: true

# Daily slice of the one-time pass that rewrites iNaturalist's
# "Mushroom Observer URL" field values to the /obs/ form and resyncs
# the reflection behind each one (#5357, #4215). The work itself lives
# in Inat::URLBackfill; this schedules it, keeps one run from
# overlapping another, and decides what a human hears about.
#
# Writes are paced at one per second and a run is time-boxed, so the
# pass takes weeks -- see config/recurring.yml for the schedule. When
# it finishes, the daily run costs one API call and says so, until
# someone removes it.
class InatURLBackfillJob < ApplicationJob
  queue_as :maintenance

  # One run at a time: a retry from /jobs, or a console perform_now,
  # would otherwise walk the same cursor as the scheduled run and
  # rewind it. `duration` has to outlast the longest run (it defaults
  # to 3 minutes, which a time-boxed run would outlive, leaving the
  # limit unenforced); `:discard` drops today's run if yesterday's is
  # somehow still going, rather than queueing it behind.
  limits_concurrency(key: -> { "inat_url_backfill" }, to: 1,
                     duration: 4.hours, on_conflict: :discard)

  # Set `time_limit` well under the gap to the next maintenance job.
  def perform(time_limit: Inat::URLBackfill::DEFAULT_TIME_LIMIT,
              max_writes: 0)
    return unless configured?

    result = run_backfill(time_limit, max_writes)
    log("InatURLBackfillJob: #{result.summary}")
    result.alerts.each { |message| alert(message) }
    alert_write_failures(result)
    alert_pass_complete if result.complete?
  end

  private

  # Silence rather than a daily failure when no credential is set: the
  # recurring entry ships before the token is installed on the server,
  # and again after the pass is retired.
  def configured?
    return true if Inat::URLBackfill::Client.configured?

    log("InatURLBackfillJob: no iNat OAuth access token configured")
    false
  end

  def run_backfill(time_limit, max_writes)
    Inat::URLBackfill.new(
      budget: Inat::URLBackfill::Budget.new(time_limit: time_limit,
                                            max_writes: max_writes),
      logger: method(:log)
    ).call
  end

  # One message per run, not one per failure: distinct alert texts are
  # distinct Slack posts, so a bad afternoon at iNat would otherwise
  # arrive as dozens of them. The values stay unrewritten and the next
  # pass over them retries.
  def alert_write_failures(result)
    failures = result.counts[:write_failed]
    return unless failures&.positive?

    alert("iNat URL backfill: #{failures} field value " \
          "#{"write".pluralize(failures)} rejected by iNat this run. See " \
          "job.log for the ids.")
  end

  # The nag that ends the pass: it repeats daily until someone acts on
  # it, which is the point.
  def alert_pass_complete
    alert("iNat URL backfill: pass complete, no values left to rewrite. " \
          "Remove the inat_url_backfill entry from config/recurring.yml, " \
          "this job, Inat::URLBackfill, and the backfill_access_token " \
          "credential.")
  end
end
