# frozen_string_literal: true

require("test_helper")

class Inat::ImportDigestTest < UnitTestCase
  include ActiveJob::TestHelper

  def setup
    super
    # Start from a clean notification slate so only the recipients we add
    # below are notified: no trackers, no name/observation interests, and
    # the observation owner is the namer (so the owner is excluded).
    # ActionMailer::Base.deliveries isn't auto-cleared between tests in
    # this process, so a truncation test's `perform_enqueued_jobs` run
    # would otherwise find a stray mail left by an earlier test.
    ActionMailer::Base.deliveries.clear
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

  def test_truncates_when_over_the_cap_and_reports_true_total
    second_obs = observations(:minimal_unknown_obs)
    second_obs.update_columns(inat_import_id: @import.id, user_id: mary.id)
    Naming.suppress_notifications do
      Naming.create!(observation: second_obs, name: @name, user: mary)
    end
    katrina.update!(email_html: true)
    Interest.create!(target: @name, user: katrina, state: true)

    mail = with_max_digest_observations(1) do
      perform_enqueued_jobs do
        Inat::ImportDigest.deliver_for(@import)
      end
      ActionMailer::Base.deliveries.find { |m| m.to.include?(katrina.email) }
    end

    assert_not_nil(mail, "Katrina should still have received a digest")
    assert_includes(mail.subject, "2",
                    "Subject should report the true total, not the " \
                    "capped count")
    body = mail.body.to_s
    # Scope to the observation list -- the "handy links" section at the
    # bottom of the email is also a <ul><li>...</li></ul>.
    observation_items = Nokogiri::HTML5(body).css("ul:not([type]) li")
    assert_equal(1, observation_items.size,
                 "Digest body should list only the capped number of " \
                 "observations")
    assert_includes(
      body, :email_inat_import_digest_truncated.l(shown: 1, count: 2),
      "Truncated digest should tell the recipient it was truncated"
    )
  end

  def test_does_not_truncate_at_or_under_the_cap
    katrina.update!(email_html: true)
    Interest.create!(target: @name, user: katrina, state: true)

    mail = with_max_digest_observations(1) do
      perform_enqueued_jobs do
        Inat::ImportDigest.deliver_for(@import)
      end
      ActionMailer::Base.deliveries.find { |m| m.to.include?(katrina.email) }
    end

    assert_not_nil(mail, "Katrina should have received a digest")
    body = mail.body.to_s
    truncated_text = :email_inat_import_digest_truncated.l(shown: 1, count: 1)
    assert_not_includes(
      body, truncated_text,
      "An untruncated digest should not carry a truncation note"
    )
  end

  def test_isolates_one_users_mailer_failure_from_the_rest
    Interest.create!(target: @name, user: katrina, state: true)
    Interest.create!(target: @name, user: dick, state: true)
    original_build = InatImportDigestMailer.method(:build)
    failing_build = lambda do |receiver:, **kwargs|
      raise(StandardError.new("boom")) if receiver == katrina

      original_build.call(receiver:, **kwargs)
    end

    # Dick's digest should still be enqueued even though Katrina's
    # mailer build raised.
    assert_enqueued_jobs(1, only: ActionMailer::MailDeliveryJob) do
      InatImportDigestMailer.stub(:build, failing_build) do
        Inat::ImportDigest.deliver_for(@import)
      end
    end
  end

  private

  def with_max_digest_observations(value)
    original = Inat::ImportDigest::MAX_DIGEST_OBSERVATIONS
    Inat::ImportDigest.send(:remove_const, :MAX_DIGEST_OBSERVATIONS)
    Inat::ImportDigest.const_set(:MAX_DIGEST_OBSERVATIONS, value)
    yield
  ensure
    Inat::ImportDigest.send(:remove_const, :MAX_DIGEST_OBSERVATIONS)
    Inat::ImportDigest.const_set(:MAX_DIGEST_OBSERVATIONS, original)
  end
end
