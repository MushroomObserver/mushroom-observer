# frozen_string_literal: true

require("test_helper")

class VerifyImagesJobTest < ActiveJob::TestCase
  def test_calls_processor_verify_images_and_logs_summary
    result = { uploaded: ["320/1.jpg"], deleted: ["960/1.jpg", "640/2.jpg"] }
    Image::Processor.stub(:verify_images, result) do
      assert_nothing_raised { VerifyImagesJob.perform_now }
    end
  end
end
