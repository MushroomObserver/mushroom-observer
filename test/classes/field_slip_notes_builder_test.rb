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

  def test_inat_link_round_trips
    link = FieldSlipNotesBuilder.inat_link("12345")

    assert(FieldSlipNotesBuilder.inat_link?(link))
    assert_equal("12345", FieldSlipNotesBuilder.inat_code(link))
  end

  # "Other Codes" is free text, so a value can contain the iNat URL
  # without being a link we generated. A substring test would call this
  # ours, skip the wrap, and mis-extract the id.
  def test_inat_link_recognizes_only_our_own_shape
    hostile = "https://evil.example/?u=#{FieldSlipNotesBuilder::
      INAT_OBSERVATION_URL}1"

    assert_not(FieldSlipNotesBuilder.inat_link?(hostile))
    assert_equal(hostile, FieldSlipNotesBuilder.inat_code(hostile))
  end

  def test_inat_code_passes_through_a_bare_code
    assert_not(FieldSlipNotesBuilder.inat_link?("12345"))
    assert_equal("12345", FieldSlipNotesBuilder.inat_code("12345"))
  end
end
