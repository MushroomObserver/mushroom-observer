# frozen_string_literal: true

require("test_helper")

# Test things that are untestable in controller tests
class InatImportsTest < CapybaraIntegrationTestCase
  def test_inat_import_no_username
    login(rolf)
    visit(new_inat_import_path)

    page.check("inat_import_consent")
    click_on("Submit")

    assert_flash_text(:inat_missing_username.l)
    assert_selector("#title", text: :inat_import_create_title.l)
  end
end
