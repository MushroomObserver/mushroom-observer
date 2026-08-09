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
        DetectFieldSlipQRJob.perform_now(@obs.id, @image.id)
      end
    end
  end

  def test_attaches_the_decoded_slip_code
    perform_with_code("OPEN-0219")

    assert_equal("OPEN-0219", @obs.reload.field_slip.code)
    assert_includes(projects(:open_membership_project).observations.reload,
                    @obs)
  end

  # The image just proved itself to be a slip photo, so the read
  # starts right away -- by the time a reviewer arrives, the extract
  # is usually waiting.
  def test_a_fresh_attach_chains_the_extraction
    assert_enqueued_with(job: ExtractFieldSlipJob,
                         args: [@image.id, @obs.user.id]) do
      perform_with_code("OPEN-0219")
    end

    assert(FieldSlipExtract.find_by(image_id: @image.id).pending?)
  end

  # Adding photos to an already-linked observation never re-reads a
  # slip somebody may have reviewed.
  def test_no_extraction_chained_when_nothing_was_attached
    slip = FieldSlip.find_or_create_by_code("OPEN-0800", @obs.user)
    @obs.field_slip = slip
    @obs.save!

    assert_no_enqueued_jobs(only: ExtractFieldSlipJob) do
      perform_with_code("OPEN-0219")
    end
  end

  def test_leaves_the_observation_alone_when_the_photo_has_no_code
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
      DetectFieldSlipQRJob.perform_now(@obs.id, @image.id)
    end

    assert_nil(@obs.reload.occurrence)
  end

  def test_survives_vanished_records
    DetectFieldSlipQRJob.perform_now(-1, @image.id)
    DetectFieldSlipQRJob.perform_now(@obs.id, -1)

    assert_nil(@obs.reload.occurrence)
  end
end
