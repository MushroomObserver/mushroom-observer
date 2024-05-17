# frozen_string_literal: true

#  Calls `script/process_image` to create resized copies of the given original
#  image and transfer them to the image server(s).
#
class ImageProcessJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Handle the error here. For example, we can send a notification email, log
    # the error to a monitoring service, or mark the upload as failed in the
    # database. We have access to the job's arguments in the 'arguments'
    # instance method.
    image = Image.find(arguments[0])
    image.update_attribute(:transferred, false)
    log("Error processing image #{arguments[0]}: #{exception.message}")
    image.update_attribute(:upload_status, exception.message)
  end

  def perform(args)
    desc = args.pluck(:id, :ext, :set_size, :strip_gps).join(", ")
    log("Starting ImageProcessJob.perform(#{desc})")

    cmd = MO.process_image_command.
          gsub("<id>", args[:id].to_s).
          gsub("<ext>", args[:ext]).
          gsub("<set>", args[:set]).
          gsub("<strip>", args[:strip])

    log("Done with ImageProcessJob.perform(#{desc})") if system(cmd)
  end
end
