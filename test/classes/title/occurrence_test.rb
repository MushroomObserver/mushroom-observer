# frozen_string_literal: true

require("test_helper")

class Title::OccurrenceTest < UnitTestCase
  def test_page_title_uses_primary_observations_consensus_name
    occ = occurrences(:occ_field_slip_one)
    name = occ.primary_observation.name
    expected = :show_occurrence_title.t(name: name.display_name).small_author

    assert_equal(expected, Title.for(occ).page_title)
  end

  def test_document_title_uses_primary_observations_text_name
    occ = occurrences(:occ_field_slip_one)
    name = occ.primary_observation.name

    assert_equal(name.text_name, Title.for(occ).document_title)
  end

  # Occurrence#primary_observation is a required belongs_to, so this
  # path is unreachable in practice -- confirms the fallback to the
  # base Title default still works if it comes back nil.
  def test_falls_back_to_base_default_without_a_name
    stub = Object.new
    stub.define_singleton_method(:primary_observation) { nil }
    stub.define_singleton_method(:type_tag) { :occurrence }
    title = Title::Occurrence.new(stub)

    assert_equal(:occurrence.ti, title.page_title)
    assert_equal(:occurrence.ti, title.document_title)
  end
end
