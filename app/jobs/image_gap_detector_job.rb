# frozen_string_literal: true

# Occasional reconciliation pass for the image transfer pipeline (see
# #4791's target design, part 4): lists what's actually on each
# configured image server and finds already-transferred images missing
# an expected size -- drift Verifier/TransferImagesJob can't see once
# local copies are cleaned up. Always alerts on what it finds; attempts
# to regenerate from the original before re-transferring, best-effort.
class ImageGapDetectorJob < ApplicationJob
  queue_as(:maintenance)

  def perform
    result = Image::Processor.detect_gaps { |msg| log(msg) }
    log(summary(result))
    alert_unchecked(result[:unchecked])
    return if result[:gaps].empty?

    alert(gap_alert_message(result))
  end

  private

  def summary(result)
    "Found #{result[:gaps].size} gap(s), " \
      "regenerated #{result[:regenerated].size} image(s), " \
      "#{result[:unregenerable].size} unregenerable, " \
      "#{result[:unchecked].size} unchecked"
  end

  # A remote listing that failed outright (#4974) means those images
  # were skipped, not verified -- say so rather than reporting a
  # falsely-clean run. The held checkpoint re-examines them next run.
  def alert_unchecked(unchecked)
    return if unchecked.empty?

    alert("Could not check #{unchecked.size} image(s) - remote listing " \
          "failed; they will be re-examined next run - image ids: " \
          "#{unchecked}")
  end

  def gap_alert_message(result)
    affected_ids = result[:gaps].map(&:first).uniq
    "#{result[:gaps].size} gap(s) found across #{affected_ids.size} " \
      "image(s): #{result[:regenerated].size} regenerated, " \
      "#{result[:unregenerable].size} could not be regenerated - " \
      "affected image ids: #{affected_ids}"
  end
end
