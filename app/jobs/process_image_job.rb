# frozen_string_literal: true

#  Calls Image::Process to create resized copies of the given original image
#  and transfer them to the image server(s).
#
class ProcessImageJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Handle the error here. For example, you might send a notification email,
    # log the error to a monitoring service, or mark the upload as failed in your database.
    # You have access to the job's arguments in the 'arguments' instance method.
    image = args[:image]
    image.update_attribute(:transferred, false)
    # log("Error processing image #{args[:id]}: #{exception.message}")
    image.update_attribute(:upload_status, exception.message)
  end

  def perform(args)
    # desc = args.pluck(:image, :ext, :set_size, :strip_gps, :user).join(", ")
    # log("Starting ProcessImageJob.perform(#{desc})")
    processor = Image::Processor.new(args)
    processor.process
    # log("Done with ProcessImageJob.perform(#{desc})")
  end
end
