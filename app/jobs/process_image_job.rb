# frozen_string_literal: true

#  Calls `script/process_image` to create resized copies of the given original
#  image and transfer them to the image server(s).
#
class ProcessImageJob < ApplicationJob
  queue_as :default

  def perform(args)
    desc = args.pluck(:id, :ext, :set_size, :strip_gps).join(", ")
    log("Starting ProcessImageJob.perform(#{desc})")

    # image = Image.find(args[:id])
    # raise(:process_image_job_no_image.t) unless image

    cmd = MO.process_image_command.
          gsub("<id>", id.to_s).
          gsub("<ext>", ext).
          gsub("<set>", set).
          gsub("<strip>", strip)
    if !Rails.env.test? && !system(cmd)
      errors.add(:image, :runtime_image_process_failed.t(id: id))
    end
    log("Done with ProcessImageJob.perform(#{desc})")
  end
end
