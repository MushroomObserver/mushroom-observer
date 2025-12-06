# frozen_string_literal: true

require("test_helper")

class CommentTest < UnitTestCase
  include ActiveJob::TestHelper

  def setup
    super
    QueuedEmail.queue = true
  end

  def teardown
    QueuedEmail.queue = false
  end

  def test_find_object_for_all_types
    Comment::ALL_TYPES.each do |type|
      assert(AbstractModel.find_object(type.to_s, type.first.id),
             "Unable to use find_object to find #{type}")
    end
  end

  def test_user_highlighting_parsing
    do_highlight_test([], "")
    do_highlight_test([mary], mary.textile_name)
    do_highlight_test([mary], "@Mary Newbie@")
    do_highlight_test([mary], "@mary foo bar")
    do_highlight_test([mary, rolf, dick], "@mary,@rolf,@dick")
    do_highlight_test([mary, rolf, dick], "@mary@,@rolf@,@dick@")
  end

  def do_highlight_test(expected, string)
    comment = Comment.reorder(created_at: :asc).first
    assert_user_arrays_equal(expected, comment.send(:highlighted_users, string))
  end

  def test_user_highlighting_emails
    # owned by rolf, namings by rolf and mary, no comments
    obs = observations(:coprinus_comatus_obs).reload
    do_highlight_comment_where_everyone_opts_out(obs)
    do_highlight_comment_where_mary_opts_in(obs)
    do_highlight_comment_where_everyone_opts_in(obs)
  end

  def do_highlight_comment_where_everyone_opts_out(obs)
    opt_out_of_comment_responses(mary, dick, katrina)
    do_comment_test(0, obs, rolf, "@mary", "what about this?")
  end

  def do_highlight_comment_where_mary_opts_in(obs)
    opt_in_to_comment_responses(mary)
    opt_out_of_comment_responses(dick, katrina)
    do_comment_test(1, obs, rolf, "@mary", "what about this?")
    do_comment_test(1, obs, rolf, "checked", "My name is @rolf.")
    do_comment_test(1, obs, rolf, "checked",
                    "@dick - yes\n\n@mary - no\n\n@katrina - maybe")
  end

  def do_highlight_comment_where_everyone_opts_in(obs)
    opt_in_to_comment_responses(mary, dick, katrina)
    do_comment_test(3, obs, rolf, "checked",
                    "@dick - yes\n\n@mary - no\n\n@katrina - maybe")
  end

  def test_comment_notification
    # owned by rolf, namings by rolf and mary, no comments
    obs = observations(:coprinus_comatus_obs).reload
    rolf.update!(email_comments_owner: false)
    do_comment_response_where_everyone_opts_out(obs)
    do_comment_response_where_mary_opts_in(obs)
    do_comment_response_where_mary_and_dick_opt_in(obs)
    do_comment_response_where_everyone_opts_in(obs)
  end

  def do_comment_response_where_everyone_opts_out(obs)
    opt_out_of_comment_responses(rolf, mary, dick)
    do_comment_test(0, obs, rolf, "1")
  end

  def do_comment_response_where_mary_opts_in(obs)
    opt_in_to_comment_responses(mary)
    opt_out_of_comment_responses(rolf, dick)
    do_comment_test(1, obs, dick, "2") # mary because of naming
    do_comment_test(0, obs, mary, "3")
  end

  def do_comment_response_where_mary_and_dick_opt_in(obs)
    opt_in_to_comment_responses(mary, dick)
    opt_out_of_comment_responses(rolf)
    do_comment_test(1, obs, mary, "4") # dick because of comment
  end

  def do_comment_response_where_everyone_opts_in(obs)
    opt_in_to_comment_responses(rolf, mary, dick)
    do_comment_test(3, obs, katrina, "5") # rolf, mary, dick all have comments
  end

  def test_oil_and_water
    old_water_users = MO.water_users
    old_oil_users   = MO.oil_users
    MO.water_users  = [users(:rolf).id, users(:mary).id]
    MO.oil_users    = [users(:dick).id, users(:katrina).id]
    do_oil_and_water_test
  ensure
    MO.water_users = old_water_users
    MO.oil_users   = old_oil_users
  end

  # oil_and_water uses QueuedEmail::Webmaster, not deliver_later
  def do_oil_and_water_test
    do_oil_and_water_comment(0, nil, rolf, "1")
    do_oil_and_water_comment(0, nil, mary, "2")
    do_oil_and_water_comment(0, nil, roy, "3")
    do_oil_and_water_comment(1, nil, katrina, "4")
    do_oil_and_water_comment(1, nil, roy, "5")
  end

  # oil_and_water emails still use QueuedEmail::Webmaster
  def do_oil_and_water_comment(expected_count, obs, user, summary)
    old = QueuedEmail.count
    Comment.create!(target: obs, user: user, summary: summary, comment: "")
    actual_count = QueuedEmail.count - old
    assert_equal(expected_count, actual_count,
                 "Expected #{expected_count} QueuedEmail, got #{actual_count}")
  end

  def opt_out_of_comment_responses(*users)
    users.each do |user|
      user.update!(email_comments_response: false)
    end
  end

  def opt_in_to_comment_responses(*users)
    users.each do |user|
      user.update!(email_comments_response: true)
    end
  end

  # CommentMailer now uses deliver_later, so we count enqueued jobs.
  def do_comment_test(expected_count, obs, user, summary, comment = "")
    obs&.reload # (to ensure it sees chgs in user prefs)
    job_start = enqueued_jobs.size
    Comment.create!(
      target: obs,
      user: user,
      summary: summary,
      comment: comment
    )
    actual_count = enqueued_jobs.size - job_start
    assert_equal(expected_count, actual_count,
                 "Expected #{expected_count} emails, got #{actual_count}")
  end

  def test_polymorphic_joins
    Comment::ALL_TYPE_TAGS.each do |type_tag|
      assert_true(Comment.joins(type_tag))
    end
  end

  def test_scope_target
    obss = Observation.has_comments
    assert(obss.size > 1)
    obs1 = obss.first
    obs2 = obss.last
    assert_not_equal(obs1.id, obs2.id)
    assert_equal(obs1.id, Comment.target(obs1.id).first.target_id)
    assert_equal(obs1.id, Comment.target(obs1).first.target_id)
    assert_equal(obs2.id, Comment.target(obs2.id).first.target_id)
    assert_equal(obs2.id, Comment.target(obs2).first.target_id)
  end
end
