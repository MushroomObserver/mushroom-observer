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
    FieldSlip::Template::REGISTRY.each_key do |key|
      FieldSlip::Template.for(key).fields.each do |field, target|
        next if target.nil?

        assert_target_reachable(obs, key, field, target)
      end
    end
  end

  def assert_target_reachable(obs, template, field, target)
    key = target.to_s
    if key.start_with?("notes.")
      assert(key.delete_prefix("notes.").present?,
             "#{template}/#{field}: empty key")
    else
      assert_respond_to(obs, target, "#{template}/#{field}: no attribute")
    end
  end

  def test_name_field_is_review_only
    FieldSlip::Template::REGISTRY.each_key do |key|
      template = FieldSlip::Template.for(key)

      assert_nil(template.fields[template.name_field],
                 "#{key}: the ID becomes a naming, never an attribute write")
    end
  end

  # ---------- Result ----------

  def result(fields: {}, confidence: {}, template: "mo", **flags)
    FieldSlip::Extractor::Result.new(provider: "gemini", model: "m", raw: {},
                                     fields: fields, confidence: confidence,
                                     template: template, **flags)
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

  # Stringified booleans normalize; anything else is unreported.
  def test_result_normalizes_flags
    assert(result(slip_present: "False").no_slip?)
    assert_not(result(slip_present: "maybe").no_slip?)
    assert(result(template_matched: "false").template_mismatch?)
    assert_not(result(template_matched: nil).template_mismatch?)
  end

  # No slip at all is not a layout mismatch -- the two states get
  # different messages and different fixes.
  def test_result_no_slip_is_not_a_template_mismatch
    res = result(slip_present: false, template_matched: false)

    assert(res.no_slip?)
    assert_not(res.template_mismatch?)
  end

  # Unreadable-field names the model invented (or from the wrong
  # template) must not travel further.
  def test_result_unreadable_filtered_by_template
    res = result(template: "dbg",
                 unreadable: ["Species", "Trees/Shrubs", "Made Up"])

    assert_equal(["Species"], res.unreadable)
  end
end
