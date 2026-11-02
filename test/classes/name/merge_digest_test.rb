# frozen_string_literal: true

require("test_helper")

class Name::MergeDigestTest < UnitTestCase
  include ActiveJob::TestHelper

  PER_NAMING_MAILERS = %w[NameProposalMailer NamingTrackerMailer
                          NamingObserverMailer].freeze

  def setup
    super
    NameTracker.all.map(&:destroy)
    @obs = observations(:minimal_unknown_obs) # mary's
    @old_name = names(:conocybe_filaris)
    @survivor = names(:agaricus_campestris)
    Naming.suppress_notifications do
      Naming.create!(observation: @obs, name: @old_name, user: roy)
    end
    Interest.create!(target: @obs, user: katrina, state: true)
    Interest.create!(target: @obs, user: rolf, state: true)
    NameTracker.create!(name: @old_name, user: dick, note_template: "Hi",
                        approved: true)
  end

  def test_merge_sends_one_digest_per_user_and_no_naming_emails
    @survivor.merge(rolf, @old_name)

    digests = digest_args.index_by { |args| receiver_id(args) }
    assert_equal([mary.id, katrina.id, dick.id].sort, digests.keys.sort,
                 "The owner, the observation follower and the tracker " \
                 "each get one digest; the merger and the namer get none")
    assert(digests[dick.id]["tracker_moved"],
           "The tracker's digest should say the tracker moved")
    assert_not(digests[katrina.id]["tracker_moved"])
    assert_empty(mail_jobs.map(&:first) & PER_NAMING_MAILERS,
                 "A merge should send no per-naming email")
  end

  def test_tracker_of_a_name_without_namings_still_hears
    Naming.where(name: @old_name).destroy_all

    @survivor.merge(rolf, @old_name)

    digests = digest_args
    assert_equal([dick.id], digests.map { |args| receiver_id(args) })
    assert(digests.first["tracker_moved"])
  end

  def test_user_who_opted_out_of_email_gets_no_digest
    katrina.update!(no_emails: true)

    @survivor.merge(rolf, @old_name)

    assert_not_includes(digest_args.map { |args| receiver_id(args) },
                        katrina.id)
  end

  def test_enqueue_failure_for_one_user_does_not_stop_the_rest
    original = NameMergeDigestMailer.method(:build)
    calls = 0
    flaky_build = lambda do |**kwargs|
      calls += 1
      raise("boom") if calls == 1

      original.call(**kwargs)
    end
    logged = []
    NameMergeDigestMailer.stub(:build, flaky_build) do
      Rails.logger.stub(:error, ->(msg) { logged << msg }) do
        @survivor.merge(rolf, @old_name)
      end
    end

    assert_equal(3, calls, "Every recipient should be tried")
    assert_match(/enqueue failed.*boom/, logged.join)
    assert_equal(2, digest_args.size)
  end

  private

  # [mailer name, keyword args] for each enqueued mail.
  def mail_jobs
    enqueued_jobs.select { |job| job[:job] == ActionMailer::MailDeliveryJob }.
      map { |job| [job[:args][0], job[:args][3]["args"][0]] }
  end

  def digest_args
    mail_jobs.filter_map do |mailer, args|
      args if mailer == "NameMergeDigestMailer"
    end
  end

  def receiver_id(args)
    args["receiver"]["_aj_globalid"].split("/").last.to_i
  end
end
