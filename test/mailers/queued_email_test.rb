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

  # NOTE: test_comment_add_email removed - CommentAdd now uses deliver_later.
  # Mailer tested in application_mailer_test.rb.

  # test_commercial_inquiry_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_commercial_email
  # and test/controllers/images/emails_controller_test.rb

  # NOTE: test_consensus_change_email removed - ConsensusChange now uses
  # deliver_later. Mailer tested in application_mailer_test.rb.

  # test_location_change_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_location_change_email

  # test_name_change_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_name_change_email

  # NOTE: test_name_proposal_email removed - NameProposal now uses
  # deliver_later. Mailer tested in application_mailer_test.rb.

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

  # NOTE: test_observation_change_email, test_observation_destroy, and
  # test_observation_add_image_email removed - ObservationChange now uses
  # deliver_later. Mailer tested in application_mailer_test.rb.

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
