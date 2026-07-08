# frozen_string_literal: true

require("test_helper")

class RepairObservationVoteCacheJobTest < ActiveJob::TestCase
  def setup
    ActionMailer::Base.deliveries.clear
    @obs = observations(:coprinus_comatus_obs)
    @naming = namings(:coprinus_comatus_naming)
    @naming.update_column(:vote_cache, 2.5)
    @obs.update_column(:vote_cache, 0)
  end

  def test_repairs_stale_vote_cache_and_sends_alert
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      RepairObservationVoteCacheJob.perform_now
    end

    # calc_consensus recomputes from the real underlying Vote records
    # (not from the naming.vote_cache column we forced), so assert the
    # repaired obs.vote_cache converges back to the naming's recomputed
    # value, rather than pinning the exact recalculated float.
    assert_operator(@obs.reload.vote_cache.abs, :>, 0.01,
                    "Stale obs.vote_cache should be repaired to a " \
                    "real (non-zero) value")
    assert_in_delta(@naming.reload.vote_cache, @obs.vote_cache, 0.001,
                    "Repaired obs.vote_cache should match the " \
                    "consensus naming's recomputed vote_cache")
    mail = ActionMailer::Base.deliveries.last
    assert_includes(mail.subject, "1 observation(s) repaired")
    assert_includes(mail.body.to_s, "obs #{@obs.id}")
  end

  def test_dry_run_repairs_nothing_and_sends_no_mail
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      RepairObservationVoteCacheJob.perform_now(dry_run: true)
    end

    assert_equal(0, @obs.reload.vote_cache,
                 "dry_run should not touch obs.vote_cache")
  end

  def test_no_email_repairs_but_sends_no_mail
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      RepairObservationVoteCacheJob.perform_now(no_email: true)
    end

    assert_operator(@obs.reload.vote_cache.abs, :>, 0.01,
                    "no_email should still repair obs.vote_cache")
  end

  def test_idempotent_second_run_finds_nothing_to_repair
    RepairObservationVoteCacheJob.perform_now

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      RepairObservationVoteCacheJob.perform_now
    end
  end

  def test_errors_during_repair_are_caught_and_tallied_not_raised
    Observation::NamingConsensus.stub(:new, ->(_obs) { raise("boom") }) do
      assert_no_difference("ActionMailer::Base.deliveries.size") do
        RepairObservationVoteCacheJob.perform_now
      end
    end
  end
end
