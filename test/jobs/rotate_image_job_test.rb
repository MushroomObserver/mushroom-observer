# frozen_string_literal: true

require("test_helper")

class RotateImageJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  # Rotation rehashes the image inline via Image::Processor#process
  # (#4796), so there is no separate dhash job -- only a transfer.
  def test_rotates_and_enqueues_transfer_job
    image = images(:in_situ_image)
    rotated_with = nil
    fake_processor = Object.new
    fake_processor.define_singleton_method(:rotate) { |o| rotated_with = o }

    Image::Processor.stub(:new, fake_processor) do
      assert_enqueued_with(job: TransferImagesJob,
                           args: [{ image_ids: [image.id] }]) do
        RotateImageJob.perform_now(image.id, "jpg", "+90")
      end
    end
    assert_equal("+90", rotated_with)
  end

  def test_missing_image_is_a_noop
    assert_nothing_raised { RotateImageJob.perform_now(-1, "jpg", "+90") }
  end
end
