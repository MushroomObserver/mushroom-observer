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

  private

  # katrina watches the name mary will propose; drop trackers so the only
  # recipient is the name-interest holder we control.
  def watch_the_name
    NameTracker.all.map(&:destroy)
    Interest.create!(target: names(:agaricus_campestris), user: katrina,
                     state: true)
  end

  def propose_naming
    Naming.create!(observation: observations(:coprinus_comatus_obs),
                   name: names(:agaricus_campestris), user: mary)
  end
end
