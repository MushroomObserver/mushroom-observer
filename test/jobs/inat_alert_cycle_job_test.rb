# frozen_string_literal: true

require("test_helper")

# The ten-minute alert cycle (#5416).
class InatAlertCycleJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  # Its own queue, so the import half and the maintenance jobs cannot
  # delay the urgent half (config/queue.yml).
  def test_enqueues_on_the_alerts_queue
    assert_enqueued_with(job: InatAlertCycleJob, queue: "alerts") do
      InatAlertCycleJob.perform_later
    end
  end

  def test_one_message_per_admin_for_the_cycle
    mary = users(:mary)
    alerts = [project_external_site_alert]
    scanner = fake_scanner({ mary => alerts })

    assert_enqueued_emails(1) do
      Inat::AlertScanner.stub(:new, scanner) { InatAlertCycleJob.perform_now }
    end
  end

  # One message per watched name per kind (#5677), so a subject line
  # can name what was found and say whether it is a find or activity
  # on something already reported.
  def test_a_message_per_watched_name_and_kind
    mary = users(:mary)
    alerts = [
      project_external_site_alert,
      project_external_site_alert(remote_identification_id: "1000",
                                  name: "Coprinus comatus var. ovatus"),
      project_external_site_alert(
        remote_identification_id: "1001",
        kind: ProjectExternalSiteAlert::OTHER_ACTIVITY
      ),
      project_external_site_alert(remote_identification_id: "1002",
                                  remote_observation_id: "12346",
                                  name: "Agaricus campestris",
                                  target_name: "Agaricus campestris")
    ]
    scanner = fake_scanner({ mary => alerts })

    assert_enqueued_emails(3) do
      Inat::AlertScanner.stub(:new, scanner) { InatAlertCycleJob.perform_now }
    end
  end

  def test_nothing_to_say_sends_nothing
    assert_no_enqueued_emails do
      Inat::AlertScanner.stub(:new, fake_scanner({})) do
        InatAlertCycleJob.perform_now
      end
    end
  end

  # A cycle that could not read everything iNat had says so rather than
  # walking it for a quarter of an hour.
  def test_a_warning_is_raised_as_a_job_alert
    scanner = fake_scanner({}, warnings: ["too many pages"])
    raised = []
    job = InatAlertCycleJob.new
    job.define_singleton_method(:alert) { |message, **| raised << message }

    Inat::AlertScanner.stub(:new, scanner) { job.perform_now }

    assert_equal(["too many pages"], raised)
  end

  def project_external_site_alert(**args)
    ProjectExternalSiteAlert.create!(
      { project: projects(:rare_fungi_project),
        external_site: external_sites(:inaturalist),
        remote_identification_id: "999", remote_observation_id: "12345",
        name: "Coprinus comatus", target_name: "Coprinus comatus",
        kind: ProjectExternalSiteAlert::NEW_OBSERVATION,
        alerted_at: Time.zone.now }.merge(args)
    )
  end

  def fake_scanner(digests, warnings: [])
    fake = Object.new
    fake.define_singleton_method(:scan) { digests }
    fake.define_singleton_method(:alerts_sent) { digests.values.sum(&:size) }
    fake.define_singleton_method(:warnings) { warnings }
    fake
  end

  # One receiver's delivery failing cannot take the cycle down with it.
  def test_a_delivery_failure_is_logged_and_the_cycle_carries_on
    scanner = fake_scanner({ users(:mary) => [project_external_site_alert] })
    raiser = ->(**) { raise("no mail today") }
    logged = nil

    Inat::AlertScanner.stub(:new, scanner) do
      ProjectAlertMailer.stub(:build, raiser) do
        Rails.logger.stub(:error, ->(message) { logged = message }) do
          assert_nothing_raised { InatAlertCycleJob.perform_now }
        end
      end
    end

    assert_match(/no mail today/, logged)
  end
end
