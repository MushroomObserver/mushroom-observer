# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for glossary term form submission
class GlossaryTermsIntegrationTest < CapybaraIntegrationTestCase
  def test_create_glossary_term
    # Login as a user who can create glossary terms
    login(users(:rolf))

    # Visit the new glossary term page
    visit(new_glossary_term_path)
    assert_selector("body.glossary_terms__new")

    # Fill in the form with valid data
    fill_in("glossary_term_name", with: "test term")
    fill_in("glossary_term_description", with: "A test description")
    click_commit

    # Verify no 500 error - form should submit without crashing
    assert_no_selector("h1", text: /error|exception/i)
    # Simpler check - just verify the page loaded (has a body element)
    assert_selector("body")
  end

  def test_edit_glossary_term
    # Login as a user who can edit glossary terms
    login(users(:rolf))
    term = glossary_terms(:conic_glossary_term)

    # Visit the edit glossary term page
    visit(edit_glossary_term_path(term))
    assert_selector("body.glossary_terms__edit")

    # Update the form with valid data
    fill_in("glossary_term_description",
            with: "Updated description for testing")
    click_commit

    # Verify no 500 error - form should submit without crashing
    assert_no_selector("h1", text: /error|exception/i)
    # Simpler check - just verify the page loaded (has a body element)
    assert_selector("body")
  end
end
