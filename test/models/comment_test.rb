# frozen_string_literal: true

require("test_helper")

class CommentTest < UnitTestCase
  def test_user_highlighting_parsing
    do_highlight_test([], "")
    do_highlight_test([mary], "_user #{mary.id}_")
    do_highlight_test([mary], "@Mary Newbie@")
    do_highlight_test([mary], "@mary foo bar")
    do_highlight_test([mary, rolf, dick], "@mary,@rolf,@dick")
    do_highlight_test([mary, rolf, dick], "@mary@,@rolf@,@dick@")
  end

  def do_highlight_test(expected, string)
    comment = Comment.first
    assert_user_list_equal(expected, comment.send(:highlighted_users, string))
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

  def do_oil_and_water_test
    do_comment_test(0, nil, rolf, "1")
    do_comment_test(0, nil, mary, "2")
    do_comment_test(0, nil, roy, "3")
    do_comment_test(1, nil, katrina, "4")
    do_comment_test(1, nil, roy, "5")
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

  def do_comment_test(chg, obs, user, summary, comment = "")
    old = num_emails
    obs&.reload # (to ensure it sees chgs in user prefs)
    Comment.create!(
      target: obs,
      user: user,
      summary: summary,
      comment: comment
    )
    assert_equal(chg, num_emails - old, sent_emails(old))
  end

  def num_emails
    ActionMailer::Base.deliveries.length
  end

  def sent_emails(start)
    return "No emails were sent" if num_emails == start

    strs = ActionMailer::Base.deliveries[start..-1].map do |mail|
      "to: #{mail["to"]}, subject: #{mail["subject"]}"
    end
    "These emails were sent:\n" + strs.join("\n")
  end
end
