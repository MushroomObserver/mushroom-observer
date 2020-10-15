# frozen_string_literal: true

require("test_helper")

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

  def test_switch_users
    rolf.admin = true
    rolf.save!
    login!(rolf)
    assert_equal(rolf.id, User.current_id)
    click(href: /turn_admin_on/)
    assert_match(/DANGER: You are in administrator mode/, response.body)
    click(href: /switch_users/)
    open_form do |form|
      form.change("id", "mary")
      form.submit
    end
    assert_equal(mary.id, User.current_id)
    assert_match(/DANGER: You are currently logged in as mary/, response.body)
    click(href: /logout_user/)
    assert_equal(rolf.id, User.current_id)
    assert_match(/DANGER: You are in administrator mode/, response.body)
  end
end
