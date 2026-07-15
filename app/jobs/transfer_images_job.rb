# frozen_string_literal: true

# Transfers a specific set of images onto every configured image server,
# started when processing hands off a completed set of local files (or
# an iNat import batch finishes) instead of waiting for a poll to notice
# them. See Image::Processor::Verifier for the per-image transfer/verify/
# delete/mark-transferred logic. Idempotent -- safe to re-run for the same
# ids, since it only uploads what isn't already confirmed present.
class TransferImagesJob < ApplicationJob
  queue_as(:default)

  def perform(image_ids:)
    result = Image::Processor.transfer_images(image_ids) { |msg| log(msg) }
    log("Uploaded #{result[:uploaded].size}, " \
        "deleted #{result[:deleted].size}, " \
        "completed #{result[:completed].size}, " \
        "failed #{result[:failed].size}")
    return if result[:failed].empty?

    alert("Transfer failed for #{result[:failed].size} file(s) - retry with: " \
          "TransferImagesJob.perform_now(image_ids: #{image_ids})")
  end
end
