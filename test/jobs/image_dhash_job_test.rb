# frozen_string_literal: true

require("test_helper")

class ImageDhashJobTest < ActiveJob::TestCase
  def test_computes_and_stores_dhash
    unless system("command -v convert >/dev/null 2>&1")
      skip("ImageMagick `convert` not available")
    end

    image = images(:in_situ_image)
    fixture = Rails.root.join("test/images/Coprinus_comatus.jpg").to_s

    assert_nil(image.dhash)
    image.stub(:full_filepath, fixture) do
      Image.stub(:find_by, image) do
        ImageDhashJob.perform_now(image.id)
      end
    end

    assert_not_nil(image.reload.dhash)
  end

  def test_missing_image_is_a_noop
    assert_nothing_raised { ImageDhashJob.perform_now(-1) }
  end

  # process_image backgrounds script/process_image and enqueues this job
  # immediately, without waiting for the resize/transfer to finish -- so
  # the source may not be ready yet. Reschedule with backoff instead of
  # hashing a placeholder URL (#4799).
  def test_reschedules_when_source_not_ready
    image = images(:in_situ_image) # transferred: false
    image.stub(:full_filepath, "/no/such/file.jpg") do
      Image.stub(:find_by, image) do
        assert_enqueued_with(
          job: ImageDhashJob,
          args: lambda { |args|
            args[0] == image.id && args[1] == { attempt: 2 }
          }
        ) do
          ImageDhashJob.perform_now(image.id)
        end
      end
    end
    assert_nil(image.reload.dhash)
  end

  def test_reschedule_wait_doubles_each_attempt
    image = images(:in_situ_image) # transferred: false
    waits = []
    scheduled_job = Object.new
    def scheduled_job.perform_later(*, **); end

    image.stub(:full_filepath, "/no/such/file.jpg") do
      Image.stub(:find_by, image) do
        ImageDhashJob.stub(:set, lambda { |wait:|
          waits << wait
          scheduled_job
        }) do
          (1..5).each do |attempt|
            ImageDhashJob.perform_now(image.id, attempt: attempt)
          end
        end
      end
    end

    assert_equal([30.seconds, 1.minute, 2.minutes, 4.minutes, 8.minutes], waits)
  end

  def test_gives_up_after_max_attempts
    image = images(:in_situ_image) # transferred: false
    image.stub(:full_filepath, "/no/such/file.jpg") do
      Image.stub(:find_by, image) do
        ImageDhashJob.stub(:set, lambda { |*|
          flunk("Should not reschedule again")
        }) do
          ImageDhashJob.perform_now(image.id, attempt: ImageDhashJob::MAX_ATTEMPTS)
        end
      end
    end
    assert_nil(image.reload.dhash)
  end
end
