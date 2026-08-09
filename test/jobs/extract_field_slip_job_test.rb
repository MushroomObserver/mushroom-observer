# frozen_string_literal: true

require("test_helper")

class ExtractFieldSlipJobTest < ActiveJob::TestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @image = images(:in_situ_image)
    @obs.images << @image unless @obs.images.include?(@image)
  end

  def result
    FieldSlip::Extractor::Result.new(
      provider: "gemini", model: "gemini-3.6-flash", raw: {},
      fields: { "Collector" => "A. W. Wilson" }, confidence: {},
      template: "mo"
    )
  end

  def fake_extractor(res)
    extractor = Object.new
    extractor.define_singleton_method(:extract) { |_image, **| res }
    extractor
  end

  def failing_extractor
    extractor = Object.new
    extractor.define_singleton_method(:extract) do |_image, **|
      raise(FieldSlip::Extractor::Gemini::BadResponse.new("no JSON today"))
    end
    extractor
  end

  # `request` writes the pending row before the job runs, so the
  # review page has a status to show from the first moment.
  def test_request_marks_pending_and_enqueues
    assert_enqueued_with(job: ExtractFieldSlipJob,
                         args: [@image.id, users(:rolf).id]) do
      ExtractFieldSlipJob.request(image: @image, user: users(:rolf))
    end

    assert(FieldSlipExtract.find_by(image_id: @image.id).pending?)
  end

  def test_perform_records_a_completed_extract
    ExtractFieldSlipJob.request(image: @image, user: users(:rolf))

    FieldSlip::Extractor.stub(:default, fake_extractor(result)) do
      ExtractFieldSlipJob.perform_now(@image.id, users(:rolf).id)
    end

    extract = FieldSlipExtract.find_by(image_id: @image.id)

    assert(extract.complete?)
    assert_equal("A. W. Wilson", extract.value_for("Collector"))
    assert_equal(FieldSlip::Extractor::PROMPT_VERSION,
                 extract.prompt_version)
  end

  # A provider failure used to leave nothing behind but a log line;
  # now the row says what went wrong, where the retry button can see
  # it.
  def test_perform_records_a_failure_with_its_error
    ExtractFieldSlipJob.request(image: @image, user: users(:rolf))

    FieldSlip::Extractor.stub(:default, failing_extractor) do
      ExtractFieldSlipJob.perform_now(@image.id, users(:rolf).id)
    end

    extract = FieldSlipExtract.find_by(image_id: @image.id)

    assert(extract.failed?)
    assert_match(/no JSON today/, extract.error)
  end

  # A failed read retries into a fresh pending row and can complete.
  def test_a_failed_read_can_be_retried
    FieldSlipExtract.fail!(image: @image, user: users(:rolf), error: "quota")
    ExtractFieldSlipJob.request(image: @image, user: users(:rolf))

    assert(FieldSlipExtract.find_by(image_id: @image.id).pending?)

    FieldSlip::Extractor.stub(:default, fake_extractor(result)) do
      ExtractFieldSlipJob.perform_now(@image.id, users(:rolf).id)
    end

    assert(FieldSlipExtract.find_by(image_id: @image.id).complete?)
  end

  def test_survives_vanished_records
    ExtractFieldSlipJob.perform_now(-1, users(:rolf).id)
    ExtractFieldSlipJob.perform_now(@image.id, -1)

    assert_nil(FieldSlipExtract.find_by(image_id: @image.id))
  end
end
