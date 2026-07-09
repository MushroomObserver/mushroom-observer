# frozen_string_literal: true

require("test_helper")

class RetransferImagesJobTest < ActiveJob::TestCase
  def test_calls_processor_retransfer_images
    called = false
    Image::Processor.stub(:retransfer_images, -> { called = true }) do
      RetransferImagesJob.perform_now
    end
    assert(called)
  end
end
