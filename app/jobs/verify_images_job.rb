# frozen_string_literal: true

# Recurring local/remote image sync check: uploads anything missing or
# mismatched on a server, marks an image transferred only once every size
# is confirmed present and byte-matching everywhere, then deletes the
# local copies. Also replaces the old self.retransfer_images (retired,
# see #4791) -- this is now the only path that flips `transferred`.
class VerifyImagesJob < ApplicationJob
  queue_as(:maintenance)

  def perform
    result = Image::Processor.verify_images { |msg| log(msg) }
    uploaded, deleted, completed, failed, alerted =
      result.values_at(:uploaded, :deleted, :completed, :failed, :alerted).
      map(&:size)
    log("Uploaded #{uploaded}, deleted #{deleted}, completed #{completed}, " \
        "failed #{failed}, alerted #{alerted}")
    return if alerted.zero?

    alert("#{alerted} image(s) marked transferred but missing/mismatched " \
          "on a server - see job.log for #{result[:alerted].join(", ")}")
  end
end
