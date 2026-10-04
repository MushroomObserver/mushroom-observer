# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/remove_duplicate_name_trackers").to_s)

# The unique index stops the test database from holding duplicate
# trackers, so the repair tests stub the lookup to present two trackers
# as one user/Name pair.
class RemoveDuplicateNameTrackersTest < UnitTestCase
  def test_keeper_prefers_note_then_approved_then_oldest
    oldest = NameTracker.new(id: 1, approved: true)
    noted = NameTracker.new(id: 2, approved: false, note_template: "Hi")
    approved_note = NameTracker.new(id: 3, approved: true, note_template: "Hi")

    assert_equal(oldest, keeper(oldest, NameTracker.new(id: 4)),
                 "Without notes, the oldest tracker should survive")
    assert_equal(noted, keeper(oldest, noted),
                 "A tracker with a note should outrank one without")
    assert_equal(approved_note, keeper(noted, approved_note),
                 "An approved note should outrank an unapproved one")
  end

  def test_clean_data_dry_run_reports_nothing_to_do
    err = run_repair(apply: false)

    assert_match(%r{^0 user/Name pairs}, err,
                 "Fixtures hold no duplicates to report")
    assert_match(/Dry run - nothing written/, err,
                 "Dry run should say it wrote nothing")
  end

  def test_dry_run_keeps_duplicates
    keep, extra = two_trackers

    err = run_repair(apply: false, pair: [keep, extra])

    assert(NameTracker.exists?(extra.id), "Dry run should not destroy")
    assert_match(/keep #{keep.id}; remove #{extra.id}/, err,
                 "Dry run should name the tracker kept and removed")
  end

  def test_apply_destroys_extras_and_their_interests
    keep, extra = two_trackers
    interest = Interest.create!(target: extra, user: extra.user, state: true)

    err = run_repair(apply: true, pair: [keep, extra])

    assert(NameTracker.exists?(keep.id), "Kept tracker should survive")
    assert_not(NameTracker.exists?(extra.id), "Extra should be destroyed")
    assert_not(Interest.exists?(interest.id),
               "Extra tracker's Interest should be destroyed")
    assert_no_match(/Dry run/, err, "Apply should not report a dry run")
  end

  private

  def keeper(*trackers)
    DuplicateNameTrackerRemoval.keeper(trackers)
  end

  def two_trackers
    keep = NameTracker.create!(user: katrina, name: names(:lactarius),
                               note_template: "A note", approved: true)
    extra = NameTracker.create!(user: katrina, name: names(:lactarius_alpinus))
    [keep, extra]
  end

  # With `pair` ([keep, extra]), present those two trackers as one
  # duplicated user/Name pair.
  def run_repair(apply:, pair: nil)
    removal = DuplicateNameTrackerRemoval.new(apply:)
    _out, err = capture_io do
      next removal.run unless pair

      groups = [[pair.first.user_id, pair.first.name_id]]
      removal.stub(:duplicate_groups, groups) do
        NameTracker.stub(:where, pair) { removal.run }
      end
    end
    err
  end
end
