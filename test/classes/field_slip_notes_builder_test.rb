# frozen_string_literal: true

require("test_helper")

# Tests for the field-slip notes builder. The collector no longer lives
# in notes (it goes to the observation's collector column); the builder
# resolves the collector name to a User / free-text string / nil. See
# #4211.
class FieldSlipNotesBuilderTest < UnitTestCase
  def build(collector:)
    params = { field_slip: { collector: collector, field_slip_name: "",
                             field_slip_id_by: "", other_codes: "" } }
    FieldSlipNotesBuilder.new(params, field_slips(:field_slip_one))
  end

  def test_collector_resolves_known_user
    assert_equal(users(:rolf), build(collector: users(:rolf).login).collector)
  end

  def test_collector_unmatched_returns_string
    assert_equal("Jane Forager", build(collector: "Jane Forager").collector)
  end

  def test_collector_blank_returns_nil
    assert_nil(build(collector: "").collector)
  end

  def test_assemble_omits_collector_key
    notes = build(collector: users(:rolf).login).assemble
    assert_not(notes.key?(:Collector),
               "collector lives in the column, not notes")
  end
end
