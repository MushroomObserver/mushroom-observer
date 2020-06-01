# frozen_string_literal: true

require "test_helper"

# Tests which supplement controller/name_controller_test.rb
class NameControllerSupplementalTest < IntegrationTestCase
  # Email tracking template should not contain ":mailing_address"
  # because, when email is sent, that will be interpreted as
  # recipient's mailing_address
  def test_email_tracking_template_no_email_address_symbol
    visit("/account/login")
    fill_in("User name or Email address:", with: "rolf")
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    visit("/names/email_tracking/#{names(:boletus_edulis).id}")
    template = find("#notification_note_template")
    template.assert_no_text(":mailing_address")
  end
end
