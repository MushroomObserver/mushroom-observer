# frozen_string_literal: true

#  Calls `script/process_image` to create resized copies of the given original
#  image and transfer them to the image server(s).
#
class ImageTransformJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Handle the error here. For example, we can send a notification email, log
    # the error to a monitoring service, or mark the upload as failed in the
    # database. We have access to the job's arguments in the 'arguments'
    # instance method.
    image = Image.find(arguments[:id])
    # I think this is right: a transformed image needs to be retransferred
    image.update_attribute(:transferred, false)
    log("Error transforming image #{arguments[:id]}: #{exception.message}")
    image.update_attribute(:upload_status, exception.message)
  end

  def perform(args)
    desc = args.pluck(:id, :operator).join(", ")
    log("Starting ImageTransformJob.perform(#{desc})")

    cmd = "script/rotate_image <id> <operator>&".
          gsub("<id>", args[:id].to_s).
          gsub("<operator>", args[:operator])

    log("Done with ImageTransformJob.perform(#{desc})") if system(cmd)
  end
end
