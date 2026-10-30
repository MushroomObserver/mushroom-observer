# frozen_string_literal: true

require("test_helper")

class Naming::NotifyTest < UnitTestCase
  include ActiveJob::TestHelper

  def test_suppress_notifications_toggles_flag
    assert_not(Naming.notifications_suppressed?)
    Naming.suppress_notifications do
      assert(Naming.notifications_suppressed?)
    end
    assert_not(Naming.notifications_suppressed?)
  end

  def test_suppress_notifications_nests
    Naming.suppress_notifications do
      Naming.suppress_notifications do
        assert(Naming.notifications_suppressed?)
      end
      # the inner block exiting must not re-enable notifications while the
      # outer block is still running
      assert(Naming.notifications_suppressed?)
    end
    assert_not(Naming.notifications_suppressed?)
  end

  def test_suppress_notifications_clears_on_error
    assert_raises(RuntimeError) do
      Naming.suppress_notifications { raise("boom") }
    end
    assert_not(Naming.notifications_suppressed?)
  end

  def test_create_emails_sends_when_not_suppressed
    watch_the_name
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      propose_naming
    end
  end

  def test_create_emails_suppressed_sends_nothing
    watch_the_name
    assert_no_enqueued_jobs do
      Naming.suppress_notifications { propose_naming }
    end
  end

  def test_notified_user_ids_includes_name_interest_holder
    watch_the_name
    naming = Naming.suppress_notifications { propose_naming }

    assert_includes(naming.notified_user_ids, katrina.id)
  end

  def test_notified_user_ids_excludes_the_namer
    watch_the_name
    naming = Naming.suppress_notifications { propose_naming }

    assert_not_includes(naming.notified_user_ids, mary.id)
  end

  def test_notified_user_ids_includes_synonym_tracker
    NameTracker.all.map(&:destroy)
    NameTracker.create!(user: katrina, name: names(:lactarius_alpinus))
    naming = Naming.suppress_notifications do
      Naming.create!(observation: observations(:coprinus_comatus_obs),
                     name: names(:lactarius_alpigenes), user: mary)
    end

    assert_includes(naming.notified_user_ids, katrina.id,
                    "Digest should reach a tracker on an accepted synonym")
  end

  def test_create_emails_deprecated_name_notifies_accepted_name_tracker
    NameTracker.all.map(&:destroy)
    accepted = names(:lactarius_alpinus)
    NameTracker.create!(user: katrina, name: accepted)

    mails = naming_mail_to(katrina, name: names(:lactarius_alpigenes))

    assert_equal(1, mails.size,
                 "Tracker on the accepted Name should get one email")
    assert_includes(mails.first.body.to_s, edit_tracker_url(accepted),
                    "Disable link should edit the accepted Name's tracker")
  end

  def test_create_emails_accepted_name_notifies_deprecated_name_tracker
    NameTracker.all.map(&:destroy)
    deprecated = names(:lactarius_alpigenes)
    NameTracker.create!(user: katrina, name: deprecated)

    mails = naming_mail_to(katrina, name: names(:lactarius_alpinus))

    assert_equal(1, mails.size,
                 "Tracker on a deprecated synonym should get one email")
    assert_includes(mails.first.body.to_s, edit_tracker_url(deprecated),
                    "Disable link should edit the deprecated Name's tracker")
  end

  def test_create_emails_one_email_for_trackers_on_several_synonyms
    NameTracker.all.map(&:destroy)
    [names(:lactarius_alpinus), names(:lactarius_alpigenes)].each do |name|
      NameTracker.create!(user: katrina, name:)
    end

    mails = naming_mail_to(katrina, name: names(:lactarius_kuehneri))

    assert_equal(1, mails.size,
                 "User tracking several synonyms should get one email")
  end

  # A specimen-only tracker that is skipped must not stop the same user's
  # other trackers from matching.
  def test_create_emails_skipped_specimen_tracker_does_not_block_genus
    NameTracker.all.map(&:destroy)
    species = names(:lactarius_alpinus)
    genus = names(:lactarius)
    NameTracker.create!(user: katrina, name: species, require_specimen: true)
    NameTracker.create!(user: katrina, name: genus)
    observations(:coprinus_comatus_obs).update!(specimen: false)

    mails = naming_mail_to(katrina, name: species)

    assert_equal(1, mails.size,
                 "Genus tracker should still notify when the species " \
                 "tracker requires a specimen")
    assert_includes(mails.first.body.to_s, edit_tracker_url(genus),
                    "Disable link should edit the genus tracker that matched")
  end

  def test_create_emails_notifies_interest_on_synonym
    NameTracker.all.map(&:destroy)
    Interest.create!(target: names(:lactarius_alpinus), user: katrina,
                     state: true)

    mails = naming_mail_to(katrina, name: names(:lactarius_alpigenes))

    assert_equal(1, mails.size,
                 "Interest in the accepted Name should get the proposal " \
                 "email for a naming of its synonym")
  end

  private

  # Propose `name` as dick on an observation `receiver` has no interest in,
  # deliver the resulting emails, and return the ones sent to `receiver`.
  def naming_mail_to(receiver, name:)
    receiver.update!(email_html: false)
    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      Naming.create!(observation: observations(:coprinus_comatus_obs),
                     name:, user: dick)
    end
    ActionMailer::Base.deliveries.select { |m| m.to == [receiver.email] }
  end

  def edit_tracker_url(name)
    MO.http_domain +
      Rails.application.routes.url_helpers.edit_tracker_of_name_path(name.id)
  end

  # katrina watches the name mary will propose; drop trackers so the only
  # recipient is the name-interest holder we control.
  def watch_the_name
    NameTracker.all.map(&:destroy)
    Interest.create!(target: names(:conocybe_filaris), user: katrina,
                     state: true)
  end

  def propose_naming
    Naming.create!(observation: observations(:coprinus_comatus_obs),
                   name: names(:conocybe_filaris), user: mary)
  end
end
