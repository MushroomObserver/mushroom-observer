# frozen_string_literal: true

# Transfers a specific set of images onto every configured image server,
# started when processing hands off a completed set of local files (or
# an iNat import batch finishes) instead of waiting for a poll to notice
# them. See Image::Processor::Verifier for the per-image transfer/verify/
# delete/mark-transferred logic. Idempotent -- safe to re-run for the same
# ids, since it only uploads what isn't already confirmed present.
class TransferImagesJob < ApplicationJob
  # Raised (and retried) when any file's upload or remote check failed
  # this run. Never leaves the job -- retry_on either requeues or alerts.
  class UploadFailure < StandardError; end

  queue_as(:default)

  # Each image's transfer serializes on its row lock with the writers
  # that rewrite its files in place (Image#strip_gps!,
  # Image::Processor#rotate -- see Verifier#transfer_image). A slow
  # re-render can hold the lock past MySQL's wait timeout; requeue
  # instead of failing the transfer permanently.
  retry_on ActiveRecord::LockWaitTimeout, wait: 30.seconds, attempts: 5

  # A transient rsync/ssh failure is precisely what retry-with-backoff
  # exists for -- the old behavior alerted a human whose whole remedy
  # was to run the same job again (#4974). Eight polynomially-spaced
  # attempts span ~80 minutes, sized to outlast the longest observed
  # sshd connection storm (~30 minutes) before waking anyone up.
  retry_on UploadFailure, wait: :polynomially_longer,
                          attempts: 8 do |job, error|
    job.alert("#{error.message} after #{job.executions} attempts - " \
              "retry with: " \
              "#{retry_command(job.arguments.first[:image_ids])}")
  end

  # The pasteable remediation for a genuine transfer straggler; also
  # advised by StaleImageFilesJob's hourly scan.
  def self.retry_command(image_ids)
    "TransferImagesJob.perform_now(image_ids: #{image_ids})"
  end

  def perform(image_ids:)
    result = Image::Processor.transfer_images(image_ids) { |msg| log(msg) }
    log(summary(result))
    alert_stuck(result[:stuck])
    return if result[:failed].empty?

    raise(UploadFailure.new("Transfer failed for " \
                            "#{result[:failed].size} file(s)"))
  end

  private

  def summary(result)
    "Uploaded #{result[:uploaded].size}, " \
      "deleted #{result[:deleted].size}, " \
      "completed #{result[:completed].size}, " \
      "failed #{result[:failed].size}, " \
      "stuck #{result[:stuck].size}"
  end

  # Retrying the transfer can't help a stuck image -- its derivative
  # sizes were never generated (processing died mid-#process, #4974) --
  # so don't raise UploadFailure for it; advise reprocessing instead.
  # First execution only: UploadFailure retries re-run the whole job,
  # and the stuck state can't change between retries, so re-alerting
  # on each of the 8 attempts would just spam #alerts.
  def alert_stuck(stuck)
    return if stuck.blank? || executions > 1

    alert("#{stuck.size} image(s) have missing local sizes past " \
          "#{StaleImageFilesJob::STALE_THRESHOLD.inspect} - processing " \
          "died? Reprocess with: " \
          "#{Image::Processor.reprocess_command(stuck)}")
  end
end
