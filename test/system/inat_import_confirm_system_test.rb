# frozen_string_literal: true

require("application_system_test_case")

# Regression coverage for #5066: submitting the New iNat Import form
# (Turbo-submitted, turbo: true) must land on the Confirm page, not
# hang. confirm_import's success render used to be a plain 200 at the
# same URL, which Turbo Drive requires either a redirect or a non-2xx
# status for -- the page silently hung with no visible error (submit
# button stays disabled, nothing happens).
class InatImportConfirmSystemTest < ApplicationSystemTestCase
  include Inat::Constants

  def test_new_form_submission_reaches_confirm_page
    user = users(:rolf)
    stub_request(:get, %r{#{Regexp.escape(API_BASE)}/observations}o).
      to_return(status: 200, body: { total_results: 3 }.to_json)

    login!(user)
    visit(new_inat_import_path)
    assert_selector("#inat_import_inat_username")

    # Default radio choice is "All my iNat observations" -- no ids/url
    # field to fill in.
    fill_in("inat_import_inat_username", with: "anyone")
    check("inat_import_consent")

    click_commit

    # The Confirm page, not a hung New form: #expected_count only
    # exists on Confirm.
    assert_selector("#expected_count", text: "3", wait: 6)
    assert_button(:inat_import_confirm_proceed.l)
    assert_button(:inat_import_confirm_go_back.l)
  end
end
