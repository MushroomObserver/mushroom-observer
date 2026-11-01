# frozen_string_literal: true

require("test_helper")

class FieldSlip::Extractor::GeminiTest < UnitTestCase
  API = %r{generativelanguage\.googleapis\.com/v1beta/models/}
  KEY = "test-key"
  # Distinct payloads so a test can tell WHICH source the adapter read
  # from by looking at what it sent, rather than asking WebMock whether
  # a fetch happened -- see `assert_sent_image`.
  REMOTE_BYTES = "\xFF\xD8jpegbytes".b
  LOCAL_BYTES = "\xFF\xD8localbytes".b

  def setup
    @obs = observations(:minimal_unknown_obs)
    @image = images(:in_situ_image)
    @obs.images << @image unless @obs.images.include?(@image)
    @context = FieldSlip::Extractor::Context.new(observation: @obs)
    stub_image_fetch
    write_local_image
  end

  def teardown
    FileUtils.rm_f(local_image_path)
    super
  end

  def stub_image_fetch
    stub_request(:get, /images\.mushroomobserver\.org/).
      to_return(status: 200, body: REMOTE_BYTES)
  end

  # The test environment resolves an image to a `file://` URL and the
  # fixtures have nothing behind it, so put a file there. Reading from
  # disk is also the production path whenever MO holds the file.
  def write_local_image
    FileUtils.mkdir_p(File.dirname(local_image_path))
    File.binwrite(local_image_path, LOCAL_BYTES)
  end

  def stub_gemini(payload, model_version: "gemini-3.6-flash", status: 200)
    body = { "candidates" => [{ "content" => { "parts" =>
               [{ "text" => payload }] } }],
             "modelVersion" => model_version }
    stub_request(:post, API).
      with { |req| @request = req }.
      to_return(status: status, body: body.to_json,
                headers: { "Content-Type" => "application/json" })
  end

  def json_payload(fields: {}, confidence: {}, **extra)
    { fields: fields, confidence: confidence, **extra }.to_json
  end

  def extract(api_key: KEY, **)
    FieldSlip::Extractor::Gemini.new(api_key: api_key, **).
      extract(@image, context: @context)
  end

  def test_missing_key_raises_a_named_error
    with_gemini_credentials(nil) do
      error = assert_raises(FieldSlip::Extractor::Gemini::MissingKey) do
        FieldSlip::Extractor::Gemini.new.extract(@image, context: @context)
      end

      assert_match(/credentials\.gemini\.key/, error.message)
    end
  end

  def test_returns_fields_and_confidence
    stub_gemini(json_payload(fields: { "Collector" => "Scott Shapiro" },
                             confidence: { "Collector" => "high" }))

    result = extract

    assert_equal("Scott Shapiro", result.value_for("Collector"))
    assert_equal("high", result.confidence_for("Collector"))
    assert_equal("gemini", result.provider)
  end

  def test_reports_when_the_image_holds_no_slip
    stub_gemini(json_payload(fields: { "Collector" => nil },
                             confidence: {}, slip_present: false))

    result = extract

    assert(result.no_slip?)
    assert_equal(false, result.slip_present)
  end

  # A null means "no value from this image" either way, but only a
  # field listed unreadable is worth looking for in another photo.
  def test_separates_unreadable_fields_from_empty_boxes
    stub_gemini(json_payload(fields: { "Substrate" => nil, "Habit" => nil },
                             unreadable: ["Substrate"]))

    result = extract

    assert_equal(["Substrate"], result.unreadable)
    assert(result.unreadable?("Substrate"))
    assert_not(result.unreadable?("Habit"), "an empty box is not unreadable")
  end

  def test_unreadable_drops_names_that_are_not_slip_fields
    stub_gemini(json_payload(fields: {},
                             unreadable: ["Substrate", "Invented Field"]))

    assert_equal(["Substrate"], extract.unreadable)
  end

  def test_unreadable_defaults_to_empty_when_not_reported
    stub_gemini(json_payload(fields: { "Collector" => "Scott Shapiro" }))

    assert_empty(extract.unreadable)
  end

  # A model that stringifies its booleans must still be understood --
  # reading "false" as unknown would quietly merge a specimen photo's
  # invented values (Copilot review on PR #4993).
  def test_a_stringified_flag_is_still_understood
    stub_gemini(json_payload(fields: {}, slip_present: "false"))

    result = extract

    assert(result.no_slip?)
    assert_equal(false, result.slip_present)
  end

  def test_a_flag_that_is_neither_true_nor_false_reads_as_unreported
    stub_gemini(json_payload(fields: {}, slip_present: "maybe"))

    result = extract

    assert_not(result.no_slip?)
    assert_nil(result.slip_present)
  end

  def test_a_read_that_saw_a_slip_is_not_flagged
    stub_gemini(json_payload(fields: { "Collector" => "Scott Shapiro" },
                             confidence: { "Collector" => "high" },
                             slip_present: true))

    assert_not(extract.no_slip?)
  end

  # The result records which layout the prompt asked for, and whether
  # the model said the photographed slip was that layout at all.
  def test_reports_the_template_and_a_mismatch
    stub_gemini(json_payload(fields: {}, slip_present: true,
                             template_matched: "false"))

    result = extract

    assert_equal(@context.template.key, result.template)
    assert(result.template_mismatch?)
  end

  def test_missing_template_matched_is_not_a_mismatch
    stub_gemini(json_payload(fields: { "Collector" => "Scott Shapiro" }))

    result = extract

    assert_nil(result.template_matched)
    assert_not(result.template_mismatch?)
  end

  def test_a_stringified_true_is_understood_too
    stub_gemini(json_payload(fields: {}, slip_present: "TRUE"))

    result = extract

    assert_not(result.no_slip?)
    assert_equal(true, result.slip_present)
  end

  # A provider (or prompt version) that never reported the flag must not
  # read as "no slip here" -- absence is not evidence.
  def test_missing_slip_present_is_not_treated_as_absent
    stub_gemini(json_payload(fields: { "Collector" => "Scott Shapiro" }))

    result = extract

    assert_not(result.no_slip?)
    assert_nil(result.slip_present)
  end

  # The alias is what gets requested; the concrete model the API reports
  # is what gets recorded, so provenance survives the indirection.
  def test_records_the_model_the_api_actually_ran
    stub_gemini(json_payload, model_version: "gemini-3.6-flash")

    assert_equal("gemini-3.6-flash",
                 extract(model: "gemini-flash-latest").model)
  end

  def test_falls_back_to_the_requested_model_when_none_reported
    stub_gemini(json_payload, model_version: nil)

    assert_equal("some-model", extract(model: "some-model").model)
  end

  def test_requests_the_configured_model
    stub_gemini(json_payload)

    extract(model: "gemini-3-flash-preview")

    assert_includes(@request.uri.to_s,
                    "models/gemini-3-flash-preview:generateContent")
  end

  def test_sends_the_key_as_a_header_not_a_query_param
    stub_gemini(json_payload)

    extract

    assert_equal(KEY, @request.headers["X-Goog-Api-Key"])
    assert_not_includes(@request.uri.query.to_s, KEY)
  end

  def test_sends_the_prompt_and_the_image
    stub_gemini(json_payload)

    extract

    parts = JSON.parse(@request.body).dig("contents", 0, "parts")

    assert_includes(parts.first["text"], "Field Slip Code")
    assert_equal("image/jpeg", parts.last.dig("inline_data", "mime_type"))
    assert(parts.last.dig("inline_data", "data").present?)
  end

  # Asking for JSON doesn't stop a model fencing it; unwrapping is the
  # difference between a working read and a hard failure.
  def test_unwraps_a_fenced_json_response
    stub_gemini("```json\n#{json_payload(fields: { "ID" => "Boletus" })}\n```")

    assert_equal("Boletus", extract.value_for("ID"))
  end

  def test_non_json_response_raises_bad_response
    stub_gemini("I'm afraid I can't do that")

    assert_raises(FieldSlip::Extractor::Gemini::BadResponse) { extract }
  end

  def test_missing_fields_key_yields_an_empty_result
    stub_gemini({ notes: "nothing legible" }.to_json)

    result = extract

    assert_nil(result.value_for("Collector"))
    assert_equal("low", result.confidence_for("Collector"))
  end

  def test_http_error_propagates
    stub_request(:post, API).to_return(status: 404, body: "{}")

    assert_raises(RestClient::NotFound) { extract }
  end

  # Reading a file MO already holds beats going out to the network --
  # faster, and it means this doesn't need DNS for a local image.
  def test_reads_the_local_file_when_one_exists
    stub_gemini(json_payload(fields: { "ID" => "Local" }))

    assert_equal("Local", extract.value_for("ID"))
    assert_sent_image(LOCAL_BYTES)
  end

  # A local path MO does not actually hold gets a named error rather
  # than RestClient rejecting a file:// URL as "not an HTTP URI".
  def test_missing_local_file_raises_a_named_error
    stub_gemini(json_payload)
    # A different fixture, deliberately: tests share a filesystem, so
    # deleting the file THIS test's image resolves to would pull it out
    # from under another test running in parallel.
    other = images(:turned_over_image)

    assert_raises(FieldSlip::Extractor::Gemini::MissingImage) do
      FieldSlip::Extractor::Gemini.new(api_key: KEY).
        extract(other, context: @context)
    end
  end

  def test_fetches_remotely_when_the_url_is_http
    stub_gemini(json_payload)
    remote = Struct.new(:url).new(
      "https://images.mushroomobserver.org/1280/#{@image.id}.jpg"
    )

    @image.stub(:image_url, remote) do
      FieldSlip::Extractor::Gemini.new(api_key: KEY).
        extract(@image, context: @context)
    end

    assert_sent_image(REMOTE_BYTES)
  end

  # Credentials supply both key and model when the caller passes neither.
  def test_reads_key_and_model_from_credentials
    stub_gemini(json_payload)
    creds = ActiveSupport::OrderedOptions.new
    creds[:key] = KEY
    creds[:model] = "gemini-from-credentials"

    with_gemini_credentials(creds) do
      FieldSlip::Extractor::Gemini.new.extract(@image, context: @context)
    end

    assert_includes(@request.uri.to_s,
                    "models/gemini-from-credentials:generateContent")
  end

  # ---------- read_slip_code: the pass-1 code-only read ----------

  def read_slip_code(api_key: KEY)
    FieldSlip::Extractor::Gemini.new(api_key: api_key).read_slip_code(@image)
  end

  def test_read_slip_code_returns_the_printed_code
    stub_gemini({ slip_present: true, code: "2026-NAMA-0205" }.to_json)

    assert_equal("2026-NAMA-0205", read_slip_code)
  end

  def test_read_slip_code_is_nil_when_no_slip_is_present
    stub_gemini({ slip_present: false, code: nil }.to_json)

    assert_nil(read_slip_code)
  end

  def test_read_slip_code_is_nil_when_the_code_is_blank
    stub_gemini({ slip_present: true, code: "" }.to_json)

    assert_nil(read_slip_code)
  end

  def test_read_slip_code_raises_without_a_key
    with_gemini_credentials(nil) do
      assert_raises(FieldSlip::Extractor::Gemini::MissingKey) do
        FieldSlip::Extractor::Gemini.new.read_slip_code(@image)
      end
    end
  end

  private

  # Which bytes reached the provider, read off THIS test's captured
  # request. WebMock's registry is never reset in this suite, so
  # `assert_requested`/`assert_not_requested` answer "did any test in
  # this process make that call?" -- which passed locally and failed on
  # CI purely on test order.
  def assert_sent_image(bytes)
    sent = JSON.parse(@request.body).
           dig("contents", 0, "parts", 1, "inline_data", "data")

    assert_equal(Base64.strict_encode64(bytes), sent)
  end

  # `Rails.application.credentials` answers `gemini` through
  # method_missing, which Minitest's `stub` cannot alias, so define the
  # singleton outright and take it away again.
  def with_gemini_credentials(value)
    creds = Rails.application.credentials
    creds.define_singleton_method(:gemini) { value }
    yield
  ensure
    creds.singleton_class.remove_method(:gemini)
  end

  # Wherever the environment's image precedence actually resolves to --
  # `file://` in test, a root-relative web path in development -- mapped
  # to disk the same way the adapter does it.
  def local_image_path
    resolved = @image.image_url(FieldSlip::Extractor::Gemini::IMAGE_SIZE).
               url.sub(/\?\d+\z/, "")
    return resolved.delete_prefix("file://") if resolved.start_with?("file://")

    prefix = MO.image_sources.dig(:local, :read).to_s
    File.join(MO.local_image_files, resolved.delete_prefix("#{prefix}/"))
  end
end
