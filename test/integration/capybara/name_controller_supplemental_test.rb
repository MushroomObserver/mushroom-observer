# frozen_string_literal: true

require("test_helper")

# Tests which supplement controller/name_controller_test.rb
class NameControllerSupplementalTest < CapybaraIntegrationTestCase
  # Email tracking template should not contain ":mailing_address"
  # because, when email is sent, that will be interpreted as
  # recipient's mailing_address
  def test_email_tracking_template_no_email_address_symbol
    login(rolf)

    visit("/name/email_tracking/#{names(:boletus_edulis).id}")
    template = find("#name_tracker_note_template")
    template.assert_no_text(":mailing_address")
  end
end
