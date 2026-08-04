# frozen_string_literal: true

require("test_helper")

class FieldSlip::ExtractorTest < UnitTestCase
  def test_for_returns_the_named_adapter
    assert_instance_of(FieldSlip::Extractor::Gemini,
                       FieldSlip::Extractor.for(:gemini))
    assert_instance_of(FieldSlip::Extractor::Gemini,
                       FieldSlip::Extractor.for("gemini"))
  end

  def test_for_rejects_an_unknown_provider
    assert_raises(ArgumentError) { FieldSlip::Extractor.for(:tesseract) }
  end

  def test_default_is_gemini
    assert_instance_of(FieldSlip::Extractor::Gemini,
                       FieldSlip::Extractor.default)
  end

  # Every field either maps to somewhere on the Observation or is
  # deliberately review-only. A new field with a typo'd target would
  # otherwise fail silently at save time.
  def test_field_targets_are_reachable
    obs = observations(:minimal_unknown_obs)
    FieldSlip::Extractor::FIELDS.each do |field, target|
      next if target.nil?

      key = target.to_s
      if key.start_with?("notes.")
        assert(key.delete_prefix("notes.").present?, "#{field}: empty key")
      else
        assert_respond_to(obs, target, "#{field}: no such attribute")
      end
    end
  end

  def test_name_field_is_review_only
    assert_nil(FieldSlip::Extractor::FIELDS[FieldSlip::Extractor::NAME_FIELD],
               "the ID becomes a naming, never an attribute write")
  end

  # ---------- Result ----------

  def result(fields: {}, confidence: {})
    FieldSlip::Extractor::Result.new(provider: "gemini", model: "m", raw: {},
                                     fields: fields, confidence: confidence)
  end

  def test_result_reads_values_and_confidence
    res = result(fields: { "Date" => "2026-07-30" },
                 confidence: { "Date" => "medium" })

    assert_equal("2026-07-30", res.value_for("Date"))
    assert_equal("medium", res.confidence_for("Date"))
  end

  # An unrecognized level is treated as low rather than trusted: the
  # confidence drives what a reviewer looks at first.
  def test_result_confidence_falls_back_to_low
    res = result(confidence: { "Date" => "pretty sure" })

    assert_equal("low", res.confidence_for("Date"))
    assert_equal("low", res.confidence_for("Missing"))
  end
end
