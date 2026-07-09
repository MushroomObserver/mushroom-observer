# frozen_string_literal: true

require("test_helper")

class ProcessImageJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  def test_processes_and_enqueues_dhash_job
    image = images(:in_situ_image)
    processed = false
    fake_processor = Object.new
    fake_processor.define_singleton_method(:process) { processed = true }

    Image::Processor.stub(:new, fake_processor) do
      assert_enqueued_with(job: ImageDhashJob, args: [image.id]) do
        ProcessImageJob.perform_now(image.id, "jpg", false)
      end
    end
    assert(processed)
  end

  def test_missing_image_is_a_noop
    assert_nothing_raised { ProcessImageJob.perform_now(-1, "jpg", false) }
  end
end
