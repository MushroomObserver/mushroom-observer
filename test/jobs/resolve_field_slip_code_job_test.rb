# frozen_string_literal: true

require("test_helper")

class ResolveFieldSlipCodeJobTest < ActiveJob::TestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @obs.update!(occurrence: nil)
    @image = images(:in_situ_image)
    @obs.images << @image unless @obs.images.include?(@image)
    @user = @obs.user
  end

  def fake_reader(code)
    reader = Object.new
    reader.define_singleton_method(:read_slip_code) { |_image| code }
    reader
  end

  def perform_reading(code)
    FieldSlip::Extractor.stub(:default, fake_reader(code)) do
      ResolveFieldSlipCodeJob.perform_now(@obs.id, @image.id, @user.id)
    end
  end

  # The model reads the printed code off a slip zbar could not, the
  # slip attaches, and the full, correctly-templated extraction is
  # chained.
  def test_reads_the_code_attaches_and_chains_the_extraction
    assert_enqueued_with(job: ExtractFieldSlipJob,
                         args: [@image.id, @user.id]) do
      perform_reading("OPEN-0219")
    end

    assert_equal("OPEN-0219", @obs.reload.field_slip.code)
    assert(FieldSlipExtract.find_by(image_id: @image.id).pending?)
  end

  # No slip in the photo (the QR was a stray sticker): nothing attaches
  # and no extraction runs.
  def test_no_code_read_leaves_the_observation_alone
    assert_no_enqueued_jobs(only: ExtractFieldSlipJob) do
      perform_reading(nil)
    end

    assert_nil(@obs.reload.occurrence)
  end

  # The code named a slip already in use elsewhere, so nothing attached
  # here -- no read is chained.
  def test_no_chain_when_the_slip_does_not_attach
    FieldSlip::Extractor.stub(:default, fake_reader("OPEN-0219")) do
      FieldSlip::Attacher.stub(:attach, :in_use) do
        assert_no_enqueued_jobs(only: ExtractFieldSlipJob) do
          ResolveFieldSlipCodeJob.perform_now(@obs.id, @image.id, @user.id)
        end
      end
    end
  end

  # An observation that already carries a slip is left untouched: the
  # occurrence guard returns before any read.
  def test_noop_when_the_observation_already_has_a_slip
    slip = FieldSlip.find_or_create_by_code("OPEN-0800", @user)
    @obs.field_slip = slip
    @obs.save!

    perform_reading("OPEN-0219")

    assert_equal("OPEN-0800", @obs.reload.field_slip.code)
  end

  # Does not re-read an image somebody may already have reviewed: an
  # existing extract short-circuits before the model is called.
  def test_skips_when_an_extract_already_exists
    FieldSlipExtract.start!(image: @image, user: @user)

    assert_no_enqueued_jobs(only: ExtractFieldSlipJob) do
      perform_reading("OPEN-0219")
    end

    assert_nil(@obs.reload.occurrence)
  end

  # A provider failure is logged, not raised, so the job does not wedge
  # -- the collector can still scan by hand.
  def test_logs_and_swallows_a_provider_failure
    reader = Object.new
    reader.define_singleton_method(:read_slip_code) do |_image|
      raise(FieldSlip::Extractor::Gemini::BadResponse.new("boom"))
    end

    FieldSlip::Extractor.stub(:default, reader) do
      Rails.logger.stub(:error, nil) do
        ResolveFieldSlipCodeJob.perform_now(@obs.id, @image.id, @user.id)
      end
    end

    assert_nil(@obs.reload.occurrence)
  end

  def test_survives_vanished_records
    ResolveFieldSlipCodeJob.perform_now(-1, @image.id, @user.id)
    ResolveFieldSlipCodeJob.perform_now(@obs.id, -1, @user.id)
    ResolveFieldSlipCodeJob.perform_now(@obs.id, @image.id, -1)

    assert_nil(@obs.reload.occurrence)
  end
end
