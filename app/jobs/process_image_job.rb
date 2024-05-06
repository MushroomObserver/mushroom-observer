# frozen_string_literal: true

#  Calls Image::Process to create resized copies of the given original image
#  and transfer them to the image server(s).
#
class ProcessImageJob < ApplicationJob
  queue_as :default

  def perform(args)
    # desc = args.pluck(:image, :ext, :set_size, :strip_gps, :user).join(", ")
    # log("Starting ProcessImageJob.perform(#{desc})")
    processor = Image::Processor.new(args)
    processor.process
    # log("Done with ProcessImageJob.perform(#{desc})")
  end
end
