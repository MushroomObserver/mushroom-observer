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
  # it. The logger is stubbed because the test env logs errors to
  # stdout, and this deliberate failure would print into the test run.
  def test_perform_records_a_failure_with_its_error
    ExtractFieldSlipJob.request(image: @image, user: users(:rolf))

    FieldSlip::Extractor.stub(:default, failing_extractor) do
      Rails.logger.stub(:error, nil) do
        ExtractFieldSlipJob.perform_now(@image.id, users(:rolf).id)
      end
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

  # ---------- attaching the read code ----------

  def result_with_code(code)
    FieldSlip::Extractor::Result.new(
      provider: "gemini", model: "m", raw: {},
      fields: { "Field Slip Code" => code }, confidence: {}, template: "mo"
    )
  end

  # The fixture image hangs off several observations; the attach path
  # only acts on an unambiguous one, so the attach tests isolate it.
  def isolate_image_to_obs
    (@image.observations.to_a - [@obs]).each do |other|
      other.images.delete(@image)
    end
  end

  # zbar missed ~27% of the CMS fair's slip photos; the extraction read
  # the printed code off nearly all of them. A successful read now
  # attaches the slip when the observation has none.
  def test_a_read_code_attaches_the_slip_to_a_slipless_observation
    isolate_image_to_obs
    @obs.update!(occurrence: nil)

    FieldSlip::Extractor.stub(:default,
                              fake_extractor(result_with_code("OPEN-0219"))) do
      ExtractFieldSlipJob.perform_now(@image.id, users(:rolf).id)
    end

    assert_equal("OPEN-0219", @obs.reload.field_slip.code)
    assert_includes(projects(:open_membership_project).observations.reload,
                    @obs)
  end

  def test_a_read_code_never_touches_a_linked_observation
    isolate_image_to_obs
    @obs.update!(occurrence: nil)
    slip = FieldSlip.find_or_create_by_code("OPEN-0800", @obs.user)
    @obs.field_slip = slip
    @obs.save!

    FieldSlip::Extractor.stub(:default,
                              fake_extractor(result_with_code("OPEN-0219"))) do
      ExtractFieldSlipJob.perform_now(@image.id, users(:rolf).id)
    end

    assert_equal("OPEN-0800", @obs.reload.field_slip.code)
  end

  # An image on several observations makes "whose slip is this?"
  # ambiguous, and a background guess would consume the slip for the
  # right one -- only the review's human decides those.
  def test_an_ambiguous_image_attaches_nothing
    @obs.update!(occurrence: nil)

    assert_operator(@image.observations.count, :>, 1,
                    "premise: the fixture image is shared")

    FieldSlip::Extractor.stub(:default,
                              fake_extractor(result_with_code("OPEN-0219"))) do
      ExtractFieldSlipJob.perform_now(@image.id, users(:rolf).id)
    end

    assert_nil(@obs.reload.occurrence)
  end

  def test_a_read_without_a_code_attaches_nothing
    isolate_image_to_obs
    @obs.update!(occurrence: nil)

    FieldSlip::Extractor.stub(:default, fake_extractor(result)) do
      ExtractFieldSlipJob.perform_now(@image.id, users(:rolf).id)
    end

    assert_nil(@obs.reload.occurrence)
  end
end
