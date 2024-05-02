# frozen_string_literal: true

#  Calls Image::Process to create resized copies of the given original image
#  and transfer them to the image server(s).
#
class ProcessImageJob < ApplicationJob
  queue_as :default

  def perform(args)
    # log("Starting ProcessImageJob.perform(#{args[:id]}, #{args[:ext]}, #{args[:set_size]}, #{args[:strip_gps]})")
    # image = Image.find(args[:id])
    # raise(:process_image_job_no_image.t) unless image

    # processed = Image::Process.new(args)
    # log("Done with ProcessImageJob.perform(#{args[:id]}, #{args[:ext]}, #{args[:set_size]}, #{args[:strip_gps]})")
    # mark image as transferred if processed?
    # return processed?
  end
end
