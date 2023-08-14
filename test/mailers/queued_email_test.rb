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

  def test_comment_email
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

  def test_features_email
    QueuedEmail::Features.create_email(mary, "blah blah blah")
    assert_email(0,
                 flavor: "QueuedEmail::Features",
                 to: mary,
                 note: "blah blah blah")
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

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

  def test_publish_email
    QueuedEmail::Publish.create_email(rolf, mary, names(:peltigera))
    assert_email(0,
                 flavor: "QueuedEmail::Publish",
                 from: rolf,
                 to: mary,
                 name: names(:peltigera).id)
    email = QueuedEmail.first.deliver_email
    assert(email)
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

  def test_verify_api_key_email
    key = api_keys(:marys_api_key)

    QueuedEmail::VerifyAPIKey.create_email(mary, dick, key)
    assert_email(0,
                 flavor: "QueuedEmail::VerifyAPIKey",
                 from: mary,
                 to: dick,
                 user: mary.id,
                 for_user: dick.id,
                 api_key: key.id)
  end
end
