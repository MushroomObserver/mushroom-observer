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
    log("Found #{result[:gaps].size} gap(s), " \
        "regenerated #{result[:regenerated].size} image(s), " \
        "#{result[:unregenerable].size} unregenerable")
    return if result[:gaps].empty?

    alert(gap_alert_message(result))
  end

  private

  def gap_alert_message(result)
    affected_ids = result[:gaps].map(&:first).uniq
    "#{result[:gaps].size} gap(s) found across #{affected_ids.size} " \
      "image(s): #{result[:regenerated].size} regenerated, " \
      "#{result[:unregenerable].size} could not be regenerated - " \
      "affected image ids: #{affected_ids}"
  end
end
