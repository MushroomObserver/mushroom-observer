# frozen_string_literal: true

#  Calls `script/process_image` to create resized copies of the given original
#  image and transfer them to the image server(s).
#
class ImageProcessJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Handle the error here. For example, we can send a notification email, log
    # the error, or mark the upload as failed in the database.
    # We have access to the job's arguments in the 'arguments' instance method.
    # - positional args are in the arguments array by position
    # - kwargs are in a hash in the first position of the array
    image = Image.find(arguments[0][:id])
    image.update_attribute(:transferred, false)
    logger.warn(
      "Error processing image #{arguments[0][:id]}: #{exception.message}"
    )
  end

  def perform(id:, ext:, set_size:, strip_gps:)
    desc = [id, ext, set_size, strip_gps].join(", ")
    logger.debug("Starting ImageProcessJob.perform(#{desc})")

    cmd = MO.process_image_command.
          gsub("<id>", id.to_s).
          gsub("<ext>", ext).
          gsub("<set>", set_size).
          gsub("<strip>", strip_gps)

    logger.debug("Done with ImageProcessJob.perform(#{desc})") if system(cmd)
  end
end
