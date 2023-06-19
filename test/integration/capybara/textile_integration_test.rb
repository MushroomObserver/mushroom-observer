# frozen_string_literal: true

require("test_helper")

# Test adding, editing, and deleting a Sequence
class TextileIntegrationTest < CapybaraIntegrationTestCase
  def test_sequential_term_links
    login(mary)
    visit(info_textile_sandbox_path)

    fill_in("code", with: "_Aborts_\n_aborts_")
    click_on("Test")

    assert(page.has_content?("_aborts_"))
  end
end
