# frozen_string_literal: true

require("test_helper")

# Test things that are untestable in integration tests
class InatImportsTest < CapybaraIntegrationTestCase
  def test_inat_import_no_imports_designated
    login(mary)
    visit(new_inat_import_path)

    fill_in("inat_import_new_inat_username", with: "anything")
    page.check("inat_import_new_consent")
    click_on("Submit")

    assert_flash_text(:inat_list_xor_all.l)
    assert_selector("#title", text: :inat_import_create_title.l)
  end
end
