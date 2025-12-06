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

  def test_approval_email
    user = katrina
    subject = "this is the subject!"
    content = "your request has been approved"
    QueuedEmail::Approval.find_or_create_email(user, subject, content)
    email = assert_email(
      0,
      from: User.admin,
      to: user,
      subject: subject,
      note: content
    )
    assert(email.deliver_email)
  end

  def test_author_request_email
    QueuedEmail::AuthorRequest.create_email(
      mary, dick, name_descriptions(:peltigera_desc),
      "Hi", "Please make me the author"
    )
    assert_email(0,
                 flavor: "QueuedEmail::AuthorRequest",
                 from: mary,
                 to: dick,
                 obj_id: name_descriptions(:peltigera_desc).id,
                 obj_type: "name_description",
                 subject: "Hi",
                 note: "Please make me the author")
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  # NOTE: test_comment_add_email removed - CommentAdd now uses deliver_later.
  # Mailer tested in application_mailer_test.rb.

  # test_commercial_inquiry_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_commercial_email
  # and test/controllers/images/emails_controller_test.rb

  # NOTE: test_consensus_change_email removed - ConsensusChange now uses
  # deliver_later. Mailer tested in application_mailer_test.rb.

  def test_location_change_email
    QueuedEmail::LocationChange.create_email(
      rolf, mary, locations(:albion), location_descriptions(:albion_desc)
    )
    assert_email(0,
                 flavor: "QueuedEmail::LocationChange",
                 from: rolf,
                 to: mary,
                 location: locations(:albion).id,
                 description: location_descriptions(:albion_desc).id,
                 old_location_version: locations(:albion).version,
                 new_location_version: locations(:albion).version,
                 old_description_version:
                   location_descriptions(:albion_desc).version,
                 new_description_version:
                   location_descriptions(:albion_desc).version)
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

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

  def test_verify_api_key_email
    key = api_keys(:marys_api_key)

    # Dick is creating an API for Mary at Mary's request.
    # The email is from Dick to Mary, the "user" is Mary, the "app_user"
    # is Dick.
    QueuedEmail::VerifyAPIKey.create_email(mary, dick, key)
    assert_email(0,
                 flavor: "QueuedEmail::VerifyAPIKey",
                 from: dick,
                 to: mary,
                 api_key: key.id)
  end

  # test_verify_account_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_verify_email
  # and test/controllers/account_controller_test.rb

  # test_webmaster_question_email removed - migrated to deliver_later
  # See test/mailers/application_mailer_test.rb#test_webmaster_email
  # and test/controllers/admin/emails/webmaster_questions_controller_test.rb
end
