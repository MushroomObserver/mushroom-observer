# frozen_string_literal: true

require("test_helper")

# Test things that are untestable in integration tests
class InatImportsTest < CapybaraIntegrationTestCase
  def test_inat_import_no_imports_designated
    login(mary)
    visit(new_observations_inat_import_path)

    fill_in("inat_username", with: "anything")
    page.check("consent")
    click_on("Submit")

    assert_flash_text(:inat_no_imports_designated.t)
    assert_text(:create_inat_import_title.l)
  end
end
