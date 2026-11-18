# frozen_string_literal: true

require("test_helper")

# One set of digests per completed action (#5721).
class ProjectAlert::CollectorTest < UnitTestCase
  include ActiveJob::TestHelper

  def setup
    super
    @project = projects(:rare_fungi_project)
    @project.update!(start_date: nil, end_date: nil)
    @project.alerts_for(users(:mary), true)
    @target = names(:coprinus_comatus)
    @burbank = locations(:burbank)
  end

  # An action that watches nothing sends nothing, so each test says
  # what the action was.
  def act(&block)
    ProjectAlert::Collector.around(&block)
  end

  def new_observation(name: @target, location: @burbank, user: users(:rolf))
    Observation.create!(user: user, when: Time.zone.today,
                        location: location, where: location.name,
                        name: name, text_name: name.text_name)
  end

  def test_an_observation_of_a_watched_name_alerts_the_subscriber
    obs = nil
    assert_difference("ProjectAlert.count", 1) do
      act { obs = new_observation }
    end

    alert = ProjectAlert.find_by(observation: obs)

    assert_equal(@project, alert.project)
    assert_equal(@target.text_name, alert.target_name)
    assert(alert.new_observation?)
    assert_enqueued_jobs(1, only: ActionMailer::MailDeliveryJob)
  end

  # Outside a watched place, or under a name nobody watches, there is
  # nothing to say.
  def test_an_observation_elsewhere_alerts_nobody
    assert_no_difference("ProjectAlert.count") do
      act { new_observation(location: locations(:nybg_location)) }
    end
  end

  def test_an_observation_of_another_name_alerts_nobody
    assert_no_difference("ProjectAlert.count") do
      act { new_observation(name: names(:peltigera)) }
    end
  end

  def test_a_project_nobody_subscribed_to_alerts_nobody
    @project.alerts_for(users(:mary), false)

    assert_no_difference("ProjectAlert.count") do
      act { new_observation }
    end
  end

  # One action, one row: posting an observation and proposing the name
  # on it is one thing somebody did.
  def test_an_observation_and_its_naming_alert_once
    assert_difference("ProjectAlert.count", 1) do
      act do
        obs = new_observation(name: names(:fungi))
        Naming.create!(observation: obs, user: users(:rolf), name: @target)
      end
    end

    assert_enqueued_jobs(1, only: ActionMailer::MailDeliveryJob)
  end

  # A name proposed on an observation posted earlier is a find, since
  # the project had not heard about it.
  def test_a_naming_on_an_older_observation_alerts
    obs = act { new_observation(name: names(:fungi)) }

    assert_difference("ProjectAlert.count", 1) do
      act do
        Naming.create!(observation: obs, user: users(:rolf), name: @target)
      end
    end

    assert(ProjectAlert.find_by(observation: obs).new_observation?)
  end

  # A comment on an observation the project was told about is the
  # later activity it hears about.
  def test_a_comment_on_a_reported_observation_is_activity
    obs = act { new_observation }

    assert_difference("ProjectAlert.count", 1) do
      act do
        Comment.create!(target: obs, user: users(:rolf),
                        summary: "Worth a voucher", comment: "Please collect")
      end
    end

    alert = ProjectAlert.where(observation: obs).order(:id).last

    assert_equal(ProjectAlert::OTHER_ACTIVITY, alert.kind)
  end

  # An observation whose name has moved off the watched one is still
  # worth hearing about: the project was told about it, and what
  # happens next is its business.
  def test_a_comment_after_the_name_moved_is_activity
    obs = act { new_observation }
    obs.update!(name: names(:peltigera), text_name: "Peltigera")

    assert_difference("ProjectAlert.count", 1) do
      act do
        Comment.create!(target: obs, user: users(:rolf),
                        summary: "Still worth it?", comment: "What was it?")
      end
    end

    alert = ProjectAlert.where(observation: obs).order(:id).last

    assert_equal(ProjectAlert::OTHER_ACTIVITY, alert.kind)
    assert_equal(@target.text_name, alert.target_name)
  end

  # The project may have heard about it from iNaturalist rather than
  # from here, which a comment on it is activity on just the same.
  def test_a_comment_on_an_imported_observation_is_activity
    obs = act { new_observation(name: names(:peltigera)) }
    ExternalLink.create!(user: users(:rolf), target: obs,
                         external_site: external_sites(:inaturalist),
                         external_id: "12345")
    ProjectAlert.record(
      project: @project, external_site: external_sites(:inaturalist),
      identification: { id: 777, name: @target.text_name },
      observation: { id: 12_345, observed_on: obs.when },
      target_name: @target.text_name
    )

    assert_difference("ProjectAlert.count", 1) do
      act do
        Comment.create!(target: obs, user: users(:rolf),
                        summary: "Seen this?", comment: "Worth a look")
      end
    end

    alert = ProjectAlert.where(observation: obs).order(:id).last

    assert_equal(ProjectAlert::OTHER_ACTIVITY, alert.kind)
    assert_equal(@target.text_name, alert.target_name)
  end

  # An observation the project holds is its business, so a comment on
  # it is activity even when nothing has been reported about it yet.
  def test_a_comment_on_a_project_observation_is_activity
    obs = act { new_observation }
    ProjectAlert.delete_all
    @project.add_observation(obs)

    assert_difference("ProjectAlert.count", 1) do
      act do
        Comment.create!(target: obs, user: users(:rolf),
                        summary: "Seen this?", comment: "Worth a look")
      end
    end

    alert = ProjectAlert.where(observation: obs).order(:id).last

    assert_equal(ProjectAlert::OTHER_ACTIVITY, alert.kind)
    assert_equal(@target.text_name, alert.target_name)
  end

  # Joining the project is part of posting it, so the observation is
  # still news.
  def test_an_observation_added_to_the_project_as_it_is_posted_is_a_find
    obs = nil

    act do
      obs = new_observation
      @project.add_observation(obs)
    end

    alert = ProjectAlert.where(observation: obs).order(:id).last

    assert_equal(ProjectAlert::NEW_OBSERVATION, alert.kind)
  end

  # A project that reviewed an observation and left it out hears no
  # more about it -- the DNA came back and it was not what they
  # thought.
  def test_an_excluded_observation_alerts_nobody
    obs = act { new_observation }
    @project.exclude_observation(obs)

    assert_no_difference("ProjectAlert.count") do
      act do
        Comment.create!(target: obs, user: users(:rolf),
                        summary: "Still?", comment: "What came back?")
      end
    end
  end

  # A name proposed on an observation the project was told about is
  # activity on it, whichever name it is.
  def test_a_naming_of_another_name_on_a_reported_observation_is_activity
    obs = act { new_observation }

    assert_difference("ProjectAlert.count", 1) do
      act do
        Naming.create!(observation: obs, name: names(:peltigera),
                       user: users(:rolf))
      end
    end

    alert = ProjectAlert.where(observation: obs).order(:id).last

    assert_equal(ProjectAlert::OTHER_ACTIVITY, alert.kind)
    assert_equal(@target.text_name, alert.target_name)
  end

  def test_a_comment_on_an_unreported_observation_alerts_nobody
    obs = act { new_observation(name: names(:peltigera)) }

    assert_no_difference("ProjectAlert.count") do
      act do
        Comment.create!(target: obs, user: users(:rolf),
                        summary: "Hello", comment: "Nothing to do with it")
      end
    end
  end

  # An import mirrors what iNaturalist alerted on there already.
  def test_a_suppressed_action_alerts_nobody
    assert_no_difference("ProjectAlert.count") do
      act { ProjectAlert.suppress { new_observation } }
    end
  end

  # An action that raised rolled its records back, so there is nothing
  # to tell anyone about.
  def test_a_failed_action_sends_nothing
    assert_raises(RuntimeError) do
      act do
        new_observation
        raise("boom")
      end
    end

    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob)
  end

  # Nested blocks belong to the outer action, so a save inside a job
  # inside a request does not flush twice.
  def test_nested_actions_deliver_once
    act do
      act { new_observation }

      # An inner block leaves delivery to the outer one.
      assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob)
    end

    assert_enqueued_jobs(1, only: ActionMailer::MailDeliveryJob)
  end

  # Nobody collects outside an action, so a console or a script
  # changing a record mails no one.
  def test_a_change_outside_an_action_sends_nothing
    assert_no_difference("ProjectAlert.count") do
      new_observation
    end
  end

  def test_a_subscriber_who_wants_no_email_gets_none
    users(:mary).update!(no_emails: true)

    act { new_observation }

    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob)
  end
end
