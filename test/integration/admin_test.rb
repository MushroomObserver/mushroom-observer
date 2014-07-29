# encoding: utf-8

require 'test_helper'

class AdminTest < IntegrationTestCase
  def test_csrf_bug_in_review_donations_page
    rolf.admin = true
    rolf.save!
    sess = login!(rolf)
    sess.click(:href => /turn_admin_on/)
    sess.get('/support/review_donations')
    sess.open_form do |form|
      form.submit
    end
    # If it fails it renders a simple text message.
    sess.assert_select('form')
  end
end
