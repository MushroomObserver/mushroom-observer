# encoding: utf-8
require "test_helper"

class CommentTest < UnitTestCase
  def num_emails
    ActionMailer::Base.deliveries.length
  end

  def test_oil_and_water
    obs = observations(:minimal_unknown_obs)
    num = num_emails
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
end
