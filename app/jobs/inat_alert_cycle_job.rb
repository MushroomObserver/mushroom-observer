# frozen_string_literal: true

# The alert half of the iNaturalist cycle (#5416), every ten minutes:
# poll for everything newly identified as a taxon some project watches,
# match it against each project, and send each admin one message for
# the cycle.
#
# On its own queue with its own worker (config/queue.yml), because the
# import half will hold a thread for minutes at a time and an alert is
# the half that is urgent.
#
# A peak run can outlast the cycle that started it, so the concurrency
# guard is explicit, and its duration is well above ten minutes --
# Solid Queue's default is three, which would leave the limit
# unenforced. Discarding costs nothing: the watermark advances only
# when a run finishes, so whatever a discarded cycle would have found
# is found by the next one.
class InatAlertCycleJob < ApplicationJob
  queue_as :alerts

  limits_concurrency(to: 1, key: "inat_alert_cycle", duration: 30.minutes,
                     on_conflict: :discard)

  def perform
    scanner = Inat::AlertScanner.new
    digests = scanner.scan
    digests.each { |receiver, alerts| deliver(receiver, alerts) }
    log("InatAlertCycleJob: #{scanner.alerts_sent} alerts, " \
        "#{digests.size} recipients")
    scanner.warnings.each { |message| alert(message) }
  end

  private

  # Isolated per receiver so one failure cannot abort the rest of the
  # cycle, the same shape as the import digest's delivery.
  def deliver(receiver, alerts)
    ProjectAlertMailer.build(receiver: receiver, alerts: alerts).
      deliver_later
  rescue StandardError => e
    Rails.logger.error("ProjectAlertMailer enqueue failed for user " \
                       "#{receiver.id}: #{e.class}: #{e.message}")
  end
end
