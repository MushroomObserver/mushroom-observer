# encoding: utf-8
require "test_helper"

class CommentTest < UnitTestCase
  def num_emails
    ActionMailer::Base.deliveries.length
  end

  def test_oil_and_water
    num = num_emails
    MO.water_users = [users(:rolf).id, users(:mary).id]
    MO.oil_users   = [users(:dick).id, users(:katrina).id]
    Comment.create!(user: rolf, summary: "1")
    assert_equal(num, num_emails)
    Comment.create!(user: mary, summary: "2")
    assert_equal(num, num_emails)
    Comment.create!(user: roy, summary: "3")
    assert_equal(num, num_emails)
    Comment.create!(user: katrina, summary: "4")
    assert_equal(num + 1, num_emails)
    Comment.create!(user: roy, summary: "5")
    assert_equal(num + 2, num_emails)
  end

  def test_user_highlighting
    x = Comment.first
    assert_obj_list_equal([],     x.send(:highlighted_users, ""))
    assert_obj_list_equal([mary], x.send(:highlighted_users, "_user #{mary.id}_"))
    assert_obj_list_equal([mary], x.send(:highlighted_users, "@Mary Newbie@"))
    assert_obj_list_equal([mary], x.send(:highlighted_users, "@mary blah blah"))

    obs = observations(:coprinus_comatus_obs)
    num = num_emails
    mary.update_attributes!(email_comments_response: false)
    dick.update_attributes!(email_comments_response: false)
    katrina.update_attributes!(email_comments_response: false)

    Comment.create!(target: obs, user: rolf, summary: "@mary", comment: "what about this?")
    assert_equal(num, num_emails)

    mary.update_attributes!(email_comments_response: true)
    Comment.create!(target: obs, user: rolf, summary: "@mary", comment: "what about this?")
    assert_equal(num + 1, num_emails)

    Comment.create!(target: obs, user: rolf, summary: "checked", comment: "My name is @rolf.")
    assert_equal(num + 1, num_emails)

    Comment.create!(target: obs, user: rolf, summary: "checked", comment: "@dick - yes\n\n@mary - no\n\n@katrina - maybe")
    assert_equal(num + 2, num_emails)

    dick.update_attributes!(email_comments_response: true)
    katrina.update_attributes!(email_comments_response: true)
    Comment.create!(target: obs, user: rolf, summary: "checked", comment: "@dick - yes\n\n@mary - no\n\n@katrina - maybe")
    assert_equal(num + 5, num_emails)
  end
end
