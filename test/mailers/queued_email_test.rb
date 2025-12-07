# frozen_string_literal: true

require("test_helper")

class QueuedEmailTest < UnitTestCase
  def setup
    QueuedEmail.queue = true
    super
  end

  def teardown
    QueuedEmail.queue = false
    super
  end

  def test_not_silent
    assert(RunLevel.is_normal?)
  end

  # test_add_herbarium_record_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_add_herbarium_record_email
  # and test/models/herbarium_record_test.rb

  # test_approval_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_approval_email
  # and test/controllers/names/trackers/approve_controller_test.rb

  # test_author_request_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_author_email
  # and test/controllers/descriptions/author_requests_controller_test.rb

  def test_comment_add_email
    QueuedEmail::CommentAdd.find_or_create_email(
      rolf, mary, comments(:minimal_unknown_obs_comment_1)
    )
    assert_email(0,
                 flavor: "QueuedEmail::CommentAdd",
                 from: rolf,
                 to: mary,
                 comment: comments(:minimal_unknown_obs_comment_1).id)
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  # test_commercial_inquiry_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_commercial_email
  # and test/controllers/images/emails_controller_test.rb

  def test_consensus_change_email
    QueuedEmail::ConsensusChange.create_email(
      rolf, mary,
      observations(:coprinus_comatus_obs),
      names(:agaricus_campestris), names(:coprinus_comatus)
    )
    assert_email(0,
                 flavor: "QueuedEmail::ConsensusChange",
                 from: rolf,
                 to: mary,
                 observation: observations(:coprinus_comatus_obs).id,
                 old_name: names(:agaricus_campestris).id,
                 new_name: names(:coprinus_comatus).id)
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  # test_location_change_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_location_change_email

  def test_name_change_email
    QueuedEmail::NameChange.create_email(
      rolf, mary, names(:peltigera), name_descriptions(:peltigera_desc), true
    )
    assert_email(0,
                 flavor: "QueuedEmail::NameChange",
                 from: rolf,
                 to: mary,
                 name: names(:peltigera).id,
                 description: name_descriptions(:peltigera_desc).id,
                 old_name_version: names(:peltigera).version,
                 new_name_version: names(:peltigera).version,
                 old_description_version:
                   name_descriptions(:peltigera_desc).version,
                 new_description_version:
                   name_descriptions(:peltigera_desc).version,
                 review_status:
                   name_descriptions(:peltigera_desc).review_status.to_s)
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_name_proposal_email
    QueuedEmail::NameProposal.create_email(
      rolf, mary,
      observations(:coprinus_comatus_obs),
      namings(:coprinus_comatus_naming)
    )
    assert_email(0,
                 flavor: "QueuedEmail::NameProposal",
                 from: rolf,
                 to: mary,
                 naming: namings(:coprinus_comatus_naming).id,
                 observation: observations(:coprinus_comatus_obs).id)
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_naming_email
    QueuedEmail::NameTracking.create_email(
      name_trackers(:agaricus_campestris_name_tracker_with_note),
      namings(:agaricus_campestris_naming)
    )
    assert_email(
      0,
      flavor: "QueuedEmail::NameTracking",
      from: mary,
      to: rolf,
      naming: namings(:agaricus_campestris_naming).id,
      name_tracker:
      name_trackers(:agaricus_campestris_name_tracker_with_note).id
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  # test_observer_question_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_observer_question_email
  # and test/controllers/observations/emails_controller_test.rb

  def test_observation_change_email
    QueuedEmail::ObservationChange.change_observation(
      rolf, mary, observations(:coprinus_comatus_obs)
    )
    assert_email(0,
                 flavor: "QueuedEmail::ObservationChange",
                 from: rolf,
                 to: mary,
                 observation: observations(:coprinus_comatus_obs).id,
                 note: "")
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_observation_destroy
    QueuedEmail::ObservationChange.destroy_observation(
      rolf, mary, observations(:coprinus_comatus_obs)
    )
    assert_email(0,
                 flavor: "QueuedEmail::ObservationChange",
                 from: rolf,
                 to: mary,
                 observation: 0,
                 note: observations(:coprinus_comatus_obs).unique_format_name)
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_observation_add_image_email
    QueuedEmail::ObservationChange.change_images(
      rolf, mary, observations(:coprinus_comatus_obs), :added_image
    )
    assert_email(0,
                 flavor: "QueuedEmail::ObservationChange",
                 from: rolf,
                 to: mary,
                 observation: observations(:coprinus_comatus_obs).id,
                 note: "added_image")
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  # test_password_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_password_email
  # and test/controllers/account/login_controller_test.rb

  # test_project_admin_request_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_project_admin_request_email
  # and test/controllers/projects/admin_requests_controller_test.rb

  # test_user_question_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_user_question_email
  # and test/controllers/users/emails_controller_test.rb

  # test_verify_api_key_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_verify_api_key_email
  # and test/classes/api2/api_keys_test.rb

  # test_verify_account_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_verify_email
  # and test/controllers/account_controller_test.rb

  # test_webmaster_question_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_webmaster_email
  # and test/controllers/admin/emails/webmaster_questions_controller_test.rb
end
