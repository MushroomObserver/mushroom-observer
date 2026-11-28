# frozen_string_literal: true

require("test_helper")

# What iNaturalist answered about one target Name or Location, and when
# that answer stops counting.
class InatTargetLookupTest < UnitTestCase
  def setup
    super
    @name = names(:coprinus_comatus)
    @location = locations(:burbank)
  end

  def test_an_unasked_target_has_no_answer
    assert_nil(InatTargetLookup.answer_for(@name, version: 3))
  end

  def test_a_resolved_lookup_reads_back_as_its_id
    row = InatTargetLookup.record(@name, 48_701, version: 3)

    assert_equal(48_701, row.inat_id)
    assert_equal(@name.updated_at, row.target_updated_at)
    assert_not_nil(row.checked_at)
    assert_equal(48_701, InatTargetLookup.answer_for(@name, version: 3))
  end

  # A miss is worth saving -- it cost a lookup to establish -- and has
  # to stay distinguishable from a question nobody asked.
  def test_a_miss_reads_back_as_false_not_nil
    row = InatTargetLookup.record(@location, false, version: 4)

    assert_nil(row.inat_id)
    assert_equal(false, InatTargetLookup.answer_for(@location, version: 4))
  end

  def test_recording_again_moves_the_one_row
    first = InatTargetLookup.record(@name, 48_701, version: 3)
    second = InatTargetLookup.record(@name, 57_832, version: 3)

    assert_equal(first.id, second.id, "a target keeps one row")
    assert_equal(1, InatTargetLookup.where(target: @name).count)
    assert_equal(57_832, InatTargetLookup.answer_for(@name, version: 3))
  end

  def test_a_miss_can_be_resolved_later
    InatTargetLookup.record(@name, false, version: 3)
    InatTargetLookup.record(@name, 48_701, version: 3)

    assert_equal(48_701, InatTargetLookup.answer_for(@name, version: 3))
  end

  # The two ways a row goes stale. Both read as absent, which is what
  # makes the mapper ask iNaturalist again.
  def test_a_lookup_saved_under_older_matching_rules_is_not_an_answer
    InatTargetLookup.record(@name, 48_701, version: 3)

    assert_nil(InatTargetLookup.answer_for(@name, version: 4))
  end

  def test_a_lookup_saved_before_the_target_was_edited_is_not_an_answer
    InatTargetLookup.record(@name, 48_701, version: 3)
    @name.touch

    assert_nil(InatTargetLookup.answer_for(@name.reload, version: 3))
  end

  def test_a_target_saved_in_memory_does_not_make_its_row_stale
    row = InatTargetLookup.record(@name, 48_701, version: 3)
    row.update_column(:target_updated_at, @name.updated_at - 1.second)

    assert_nil(InatTargetLookup.answer_for(@name, version: 3),
               "a row older than the target is stale")

    row.update_column(:target_updated_at, @name.updated_at)

    assert_equal(48_701, InatTargetLookup.answer_for(@name, version: 3),
                 "a row level with the target is current")
  end

  # A Name is asked about taxa and a Location about places, under their
  # own matching versions, so the two kinds of answer stay apart.
  def test_a_name_and_a_location_keep_separate_answers
    InatTargetLookup.record(@name, 48_701, version: 3)
    InatTargetLookup.record(@location, 962, version: 4)

    assert_equal(48_701, InatTargetLookup.answer_for(@name, version: 3))
    assert_equal(962, InatTargetLookup.answer_for(@location, version: 4))
    assert_nil(InatTargetLookup.answer_for(@name, version: 4))
  end

  # When iNaturalist last confirmed the answer, which is what a
  # scheduled re-confirmation reads.
  def test_recording_stamps_when_inaturalist_was_asked
    before = Time.zone.now
    row = InatTargetLookup.record(@name, 48_701, version: 3)

    assert_operator(row.checked_at, :>=, before)

    row.update_column(:checked_at, 2.days.ago)
    again = InatTargetLookup.record(@name, 48_701, version: 3)

    assert_operator(again.checked_at, :>, 1.day.ago,
                    "re-confirming moves the stamp when the id has not")
  end

  def test_a_row_needs_a_version_and_a_time
    row = InatTargetLookup.new(target: @name)

    assert_not(row.valid?)
    assert_includes(row.errors.attribute_names, :matching_version)
    assert_includes(row.errors.attribute_names, :checked_at)
  end
end
