# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for publication form submission
class PublicationsFormIntegrationTest < CapybaraIntegrationTestCase
  def test_create_publication
    # Login as a user who can create publications
    login(users(:rolf))

    # Visit the new publication page
    visit(new_publication_path)
    assert_selector("body.publications__new")

    # Fill in the form with valid data
    fill_in("publication_full", with: "Test Publication Citation")
    fill_in("publication_link", with: "https://example.com/publication")
    click_commit

    # Verify no 500 error - form should submit without crashing
    assert_no_selector("h1", text: /error|exception/i)
    assert_selector("body")
  end

  def test_edit_publication
    # Login as the publication owner
    login(users(:rolf))
    publication = publications(:one_pub)

    # Visit the edit publication page
    visit(edit_publication_path(publication))
    assert_selector("body.publications__edit")

    # Update the form with valid data
    fill_in("publication_how_helped",
            with: "Updated information about how MO helped")
    click_commit

    # Verify no 500 error - form should submit without crashing
    assert_no_selector("h1", text: /error|exception/i)
    assert_selector("body")
  end
end
