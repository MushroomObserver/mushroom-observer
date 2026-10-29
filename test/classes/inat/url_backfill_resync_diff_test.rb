# frozen_string_literal: true

require("test_helper")

# Names what a resync changed, so a log line written during an
# unattended five-week pass can be checked by hand afterwards.
class Inat::URLBackfillResyncDiffTest < UnitTestCase
  Diff = Inat::URLBackfill::ResyncDiff

  def setup
    @obs = observations(:coprinus_comatus_obs)
    @before = Diff.snapshot(@obs)
  end

  def test_says_so_when_nothing_moved
    assert_equal("no visible diff", Diff.describe(@before, @before))
  end

  def test_names_the_scalar_fields_that_moved
    @obs.update!(notes: { Other: "resynced from iNat" })

    diff = Diff.describe(@before, Diff.snapshot(@obs.reload))

    assert_match(/scalars\(notes\)/, diff)
  end

  def test_counts_sequences_added_and_removed
    @obs.sequences.create!(locus: "ITS", bases: "acgt", user: @obs.user)

    diff = Diff.describe(@before, Diff.snapshot(@obs.reload))

    assert_match(%r{sequences \+1/-0}, diff)
  end

  def test_counts_images_added
    @obs.images << images(:in_situ_image)

    diff = Diff.describe(@before, Diff.snapshot(@obs.reload))

    assert_match(%r{images \+1/-0}, diff)
  end

  # The reason a synced observation used to report nothing: the taxon
  # engine reweighs votes, which leaves the naming rows alone.
  def test_counts_reweighted_votes
    vote = @obs.namings.first.votes.first
    vote.update!(value: vote.value == 1 ? 2 : 1)

    diff = Diff.describe(@before, Diff.snapshot(@obs.reload))

    assert_match(/votes 1/, diff)
  end

  def test_notices_a_new_naming
    @obs.namings.create!(name: names(:agaricus), user: @obs.user)

    diff = Diff.describe(@before, Diff.snapshot(@obs.reload))

    assert_match(%r{namings \+1/-0}, diff)
  end

  def test_notices_a_changed_thumbnail_and_consensus_name
    @obs.update_columns(thumb_image_id: images(:in_situ_image).id,
                        name_id: names(:agaricus).id)

    diff = Diff.describe(@before, Diff.snapshot(@obs.reload))

    assert_match(/thumb/, diff)
    assert_match(/name/, diff)
  end

  # A license or copyright edit on a photo the observation kept -- what
  # the image engine does when iNat's licensing changes.
  def test_counts_license_edits_on_images_the_observation_kept
    @obs.images << images(:in_situ_image)
    before = Diff.snapshot(@obs.reload)
    # update_columns: the copyright-change callback wants a current
    # user, and the diff reads the column, not the audit trail.
    images(:in_situ_image).update_columns(copyright_holder: "Someone Else")

    diff = Diff.describe(before, Diff.snapshot(@obs.reload))

    assert_match(/image-meta 1/, diff)
  end
end
