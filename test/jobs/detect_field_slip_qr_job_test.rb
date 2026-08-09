# frozen_string_literal: true

require("test_helper")

class DetectFieldSlipQRJobTest < ActiveJob::TestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @obs.update!(occurrence: nil)
    @image = images(:in_situ_image)
    @obs.images << @image unless @obs.images.include?(@image)
  end

  def perform_with_code(code)
    FieldSlip::QRDecoder.stub(:available?, true) do
      FieldSlip::QRDecoder.stub(:slip_code_in, code) do
        DetectFieldSlipQRJob.perform_now(@obs.id)
      end
    end
  end

  def test_attaches_the_decoded_slip_code
    perform_with_code("OPEN-0219")

    assert_equal("OPEN-0219", @obs.reload.field_slip.code)
    assert_includes(projects(:open_membership_project).observations.reload,
                    @obs)
  end

  def test_leaves_the_observation_alone_when_no_photo_decodes
    perform_with_code(nil)

    assert_nil(@obs.reload.occurrence)
  end

  def test_noop_when_the_observation_is_already_linked
    slip = FieldSlip.find_or_create_by_code("OPEN-0800", @obs.user)
    @obs.field_slip = slip
    @obs.save!

    perform_with_code("OPEN-0219")

    assert_equal("OPEN-0800", @obs.reload.field_slip.code)
  end

  def test_noop_when_detection_is_unavailable
    FieldSlip::QRDecoder.stub(:available?, false) do
      DetectFieldSlipQRJob.perform_now(@obs.id)
    end

    assert_nil(@obs.reload.occurrence)
  end

  def test_survives_a_vanished_observation
    DetectFieldSlipQRJob.perform_now(-1)
  end
end
