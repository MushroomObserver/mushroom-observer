# frozen_string_literal: true

# Recurring local/remote image sync check: uploads anything missing or
# mismatched on a server, deletes local copies once they're confirmed
# transferred everywhere relevant.
class VerifyImagesJob < ApplicationJob
  queue_as(:maintenance)

  def perform
    result = Image::Processor.verify_images { |msg| log(msg) }
    log("Uploaded #{result[:uploaded].size}, deleted #{result[:deleted].size}")
  end
end
