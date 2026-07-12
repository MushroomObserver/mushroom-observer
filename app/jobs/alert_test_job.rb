# frozen_string_literal: true

# On-demand end-to-end check of the job -> #alerts pipeline. Enqueue it
# with perform_later so a real Solid Queue worker runs it, then confirm
# the message lands in #alerts. Unlike the `alerts:test` rake task (which
# notifies inline in the rake process), this verifies the whole chain
# from a *worker* process: that the worker has an ExceptionNotifier
# notifier registered, that #alert routes through it, and that Slack
# delivery works. Only reachable via console/rake (no route); never add
# it to recurring.yml.
#
# Modes:
#   "alert"  (default) - unique message via #alert; always delivers.
#   "raise"            - unique message via a raise, to exercise the crash
#                        path (rescue_from -> ExceptionNotifier). Leaves a
#                        solid_queue_failed_executions row.
#   "repeat"           - a *constant* message, so repeated runs share one
#                        error_grouping signature; enqueue it several times
#                        to watch de-dup collapse a burst (delivers at
#                        counts 1, 2, 4, 8, ...; suppresses the rest within
#                        the 5-minute window).
class AlertTestJob < ApplicationJob
  queue_as :maintenance

  REPEAT_MESSAGE = "AlertTestJob de-dup probe (constant message)"

  def perform(mode: "alert")
    raise_probe if mode == "raise"

    alert(mode == "repeat" ? REPEAT_MESSAGE : unique_message(mode))
  end

  private

  def raise_probe
    raise("AlertTestJob raise-path at #{Time.zone.now} (#{job_id})")
  end

  def unique_message(mode)
    "AlertTestJob #{mode}-path at #{Time.zone.now} (#{job_id})"
  end
end
