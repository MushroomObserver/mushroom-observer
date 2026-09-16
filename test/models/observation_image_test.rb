# frozen_string_literal: true

require("test_helper")

class ObservationImageTest < UnitTestCase
  include ActiveJob::TestHelper

  def setup
    @obs = observations(:minimal_unknown_obs)
    @image = images(:turned_over_image)
  end

  def attach_image
    ObservationImage.create!(observation: @obs, image: @image)
  end

  def test_attaching_a_photo_enqueues_qr_detection
    @obs.update!(occurrence: nil)

    FieldSlip::QRDecoder.stub(:available?, true) do
      assert_enqueued_with(job: DetectFieldSlipQRJob,
                           args: [@obs.id, @image.id]) do
        attach_image
      end
    end
  end

  # An observation already in an occurrence has nothing to gain from a
  # decoded code -- the attacher would refuse anyway.
  def test_no_enqueue_when_the_observation_is_already_linked
    assert_not_nil(@obs.occurrence_id, "premise: fixture is slip-linked")

    FieldSlip::QRDecoder.stub(:available?, true) do
      assert_no_enqueued_jobs(only: DetectFieldSlipQRJob) { attach_image }
    end
  end

  def test_no_enqueue_when_detection_is_unavailable
    @obs.update!(occurrence: nil)

    assert_no_enqueued_jobs(only: DetectFieldSlipQRJob) { attach_image }
  end
end
