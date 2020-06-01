# frozen_string_literal: true

require "test_helper"

class AdminTest < IntegrationTestCase
  def test_csrf_bug_in_review_donations_page
    rolf.admin = true
    rolf.save!
    login!(rolf)
    click(href: /turn_admin_on/)
    get("/support/review_donations")
    open_form(&:submit)
    # If it fails it renders a simple text message.
    assert_select("form")
  end
end
