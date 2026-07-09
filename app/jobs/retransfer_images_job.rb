# frozen_string_literal: true

# Recurring safety net: re-transfer any image still marked untransferred
# (e.g. a process that died mid-upload before reaching the image server).
class RetransferImagesJob < ApplicationJob
  queue_as(:maintenance)

  def perform
    Image::Processor.retransfer_images
  end
end
