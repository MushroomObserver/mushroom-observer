# frozen_string_literal: true

#  Calls `script/process_image` to create resized copies of the given original
#  image and transfer them to the image server(s).
#
class ProcessImageJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Handle the error here. For example, we can send a notification email, log
    # the error to a monitoring service, or mark the upload as failed in the
    # database. We have access to the job's arguments in the 'arguments'
    # instance method.
    image = Image.find(args[:id])
    image.update_attribute(:transferred, false)
    log("Error processing image #{args[:id]}: #{exception.message}")
    image.update_attribute(:upload_status, exception.message)
  end

  def perform(args)
    desc = args.pluck(:id, :ext, :set_size, :strip_gps).join(", ")
    log("Starting ProcessImageJob.perform(#{desc})")

    # image = Image.find(args[:id])
    # raise(:process_image_job_no_image.t) unless image

    cmd = MO.process_image_command.
          gsub("<id>", args[:id].to_s).
          gsub("<ext>", args[:ext]).
          gsub("<set>", args[:set]).
          gsub("<strip>", args[:strip])
    if !Rails.env.test? && !system(cmd)
      # job cannot return errors to caller
      # errors.add(:image, :runtime_image_process_failed.t(id: args[:id]))
    end
    log("Done with ProcessImageJob.perform(#{desc})")
  end
end
