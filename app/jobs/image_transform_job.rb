# frozen_string_literal: true

#  Calls `script/process_image` to create resized copies of the given original
#  image and transfer them to the image server(s).
#
class ImageTransformJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Handle the error here. For example, we can send a notification email,
    # log the error, or mark the upload as not transferred in the database.
    # We have access to the job's arguments in the 'arguments' instance method.
    # - positional args are in the arguments array by position
    # - kwargs are in a hash in the first position of the array
    image = Image.find(arguments[0][:id])
    # I think this is right: a transformed image needs to be retransferred
    image.update_attribute(:transferred, false)
    logger.warn(
      "Error processing image #{arguments[0][:id]}: #{exception.message}"
    )
  end

  def perform(id:, operator:)
    desc = [id, operator].join(", ")
    logger.debug("Starting ImageTransformJob.perform(#{desc})")

    cmd = "script/rotate_image <id> <operator>&".
          gsub("<id>", id.to_s).
          gsub("<operator>", operator)

    logger.debug("Done with ImageTransformJob.perform(#{desc})") if system(cmd)
  end
end
