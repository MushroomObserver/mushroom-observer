# frozen_string_literal: true

require("test_helper")

class ProcessImageJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  def test_processes_and_enqueues_dhash_job
    image = images(:in_situ_image)
    processed = false
    fake_processor = fake_processor_with_errors([]) { processed = true }

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

  # #perform's return value is read directly by Image#process_image's
  # `synchronous: true` callers (API uploads) to decide whether to raise -
  # a clean transfer must return true.
  def test_perform_returns_true_when_processor_has_no_errors
    image = images(:in_situ_image)
    fake_processor = fake_processor_with_errors([]) { nil }

    result = Image::Processor.stub(:new, fake_processor) do
      ProcessImageJob.perform_now(image.id, "jpg", false)
    end

    assert(result)
  end

  # A dangling transfer failure (processor.errors non-empty) must return
  # false - ImageDhashJob still gets enqueued unconditionally either way
  # (a remote transfer failure doesn't invalidate the local file's hash).
  def test_perform_returns_false_when_processor_has_errors
    image = images(:in_situ_image)
    fake_processor = fake_processor_with_errors(["boom"]) { nil }

    result = nil
    Image::Processor.stub(:new, fake_processor) do
      assert_enqueued_with(job: ImageDhashJob, args: [image.id]) do
        result = ProcessImageJob.perform_now(image.id, "jpg", false)
      end
    end

    assert_not(result)
  end

  private

  def fake_processor_with_errors(errors, &on_process)
    fake_processor = Object.new
    fake_processor.define_singleton_method(:process, &on_process)
    fake_processor.define_singleton_method(:errors) { errors }
    fake_processor
  end
end
