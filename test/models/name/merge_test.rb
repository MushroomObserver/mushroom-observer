# frozen_string_literal: true

require("test_helper")

# Tests for Name::Merge (app/models/name/merge.rb)
class Name::MergeTest < UnitTestCase
  def test_merge_editors
    old_name = names(:peltigera)
    editors = old_name.versions.each_with_object([]) do |version, e|
      e << version.user_id
    end.uniq
    assert(editors.many?,
           "Test needs Name fixture edited by multiple users")
    user = User.find(old_name.versions.second.user_id)
    old_contribution = user.contribution

    names(:lichen).merge(nil, old_name)

    assert_equal(
      old_contribution - UserStats::ALL_FIELDS[:name_versions][:weight],
      user.reload.contribution,
      "Merging a Name edited by a user should reduce user's contribution " \
      "by #{UserStats::ALL_FIELDS[:name_versions][:weight]}"
    )
  end

  def test_merge_interests
    old_name = names(:agaricus_campestros)
    interests = old_name.interests
    assert(interests.any?, "Test needs a fixture with an interest")
    target = names(:agaricus_campestras)
    assert(target.interests.none?, "Test needs a fixture without interests")

    target.merge(nil, old_name)
    assert_equal(
      interests, target.interests,
      "Old name (#{old_name.text_name}) interests " \
      "were not moved to target (#{target.text_name})"
    )
  end

  def test_merge_orphans_log
    name1 = names(:coprinus)
    name2 = names(:fungi)
    log1 = name1.rss_log
    log2 = name2.rss_log
    assert_not_nil(log1)
    assert_not_nil(log2)
    name2.merge(nil, name1)
    assert_nil(log1.reload.target_id)
    assert_not_nil(log2.reload.target_id)
    assert_equal(:log_orphan, log1.parse_log[0][0])
    assert_equal(:log_name_merged, log1.parse_log[1][0])
  end

  # `merge` wraps every step in a transaction - a failure partway
  # through must roll back everything already moved, not leave the DB
  # half-merged with old_name still around but stripped of its data.
  def test_merge_rolls_back_all_changes_if_a_step_raises
    old_name = names(:conocybe_filaris)
    survivor = names(:coprinus_comatus)
    old_obs_ids = old_name.observations.map(&:id)
    assert(old_obs_ids.any?, "Test needs old_name to have observations")

    survivor.stub(:move_versions, ->(*) { raise("boom") }) do
      assert_raises(RuntimeError) { survivor.merge(rolf, old_name) }
    end

    assert(Name.exists?(old_name.id),
           "old_name should still exist - merge should have rolled back")
    assert_equal(old_obs_ids.sort, old_name.reload.observations.map(&:id).sort,
                 "old_name's observations should not have been moved")
  end

  # `move_mispellings` runs once early (the normal snapshot) and once
  # again immediately before `old_name.destroy` (the re-snapshot).
  # A misspelling pointed at old_name in the gap between those two
  # calls - simulating a concurrent request - must still be caught by
  # the re-snapshot rather than left with a dangling correct_spelling_id
  # once old_name is destroyed.
  def test_merge_reassigns_misspelling_created_during_merge
    old_name = names(:conocybe_filaris)
    survivor = names(:coprinus_comatus)
    racer = nil

    original_move_followings = survivor.method(:move_followings)
    survivor.stub(:move_followings, lambda { |old|
      racer = Name.create!(text_name: "Raceria", search_name: "Raceria",
                           sort_name: "Raceria", display_name: "__Raceria__",
                           rank: Name.ranks[:Genus], user: rolf)
      racer.update_column(:correct_spelling_id, old.id)
      original_move_followings.call(old)
    }) do
      survivor.merge(rolf, old_name)
    end

    assert_equal(survivor.id, racer.reload.correct_spelling_id,
                 "Misspelling created mid-merge should be caught by the " \
                 "re-snapshot before destroy, not left dangling")
  end
end
