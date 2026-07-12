# frozen_string_literal: true

# Recurring local/remote image sync check: uploads anything missing or
# mismatched on a server, deletes local copies once they're confirmed
# transferred everywhere relevant.
class VerifyImagesJob < ApplicationJob
  queue_as(:maintenance)

  def perform
    result = Image::Processor.verify_images { |msg| log(msg) }
    uploaded, deleted, failed =
      result.values_at(:uploaded, :deleted, :failed).map(&:size)
    log("Uploaded #{uploaded}, deleted #{deleted}, failed #{failed}")
  end
end
