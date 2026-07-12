# frozen_string_literal: true

require("test_helper")

class Inat::ImportDigestTest < UnitTestCase
  include ActiveJob::TestHelper

  def setup
    super
    # Start from a clean notification slate so only the recipients we add
    # below are notified: no trackers, no name/observation interests, and
    # the observation owner is the namer (so the owner is excluded).
    NameTracker.all.map(&:destroy)
    Interest.where(target_type: %w[Name Observation]).destroy_all
    @import = inat_imports(:rolf_inat_import)
    @name = names(:agaricus_campestris)
    @obs = observations(:coprinus_comatus_obs)
    @obs.update_columns(inat_import_id: @import.id, user_id: mary.id)
    # Drop this observation's fixture namings so the digest sees only the
    # single naming we create below (delete_all skips callbacks/emails).
    Naming.where(observation_id: @obs.id).delete_all
    @naming = Naming.suppress_notifications do
      Naming.create!(observation: @obs, name: @name, user: mary)
    end
  end

  def test_delivers_one_digest_per_interested_user
    Interest.create!(target: @name, user: katrina, state: true)

    assert_enqueued_jobs(1, only: ActionMailer::MailDeliveryJob) do
      Inat::ImportDigest.deliver_for(@import)
    end
  end

  def test_skips_users_who_opted_out_of_email
    katrina.update!(no_emails: true)
    Interest.create!(target: @name, user: katrina, state: true)

    assert_no_enqueued_jobs do
      Inat::ImportDigest.deliver_for(@import)
    end
  end

  def test_no_digest_when_no_one_is_interested
    assert_no_enqueued_jobs do
      Inat::ImportDigest.deliver_for(@import)
    end
  end
end
