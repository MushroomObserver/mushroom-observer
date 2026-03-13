# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for glossary term form submission
class GlossaryTermsIntegrationTest < CapybaraIntegrationTestCase
  def test_create_glossary_term
    # Login as a user who can create glossary terms
    login!(users(:rolf))

    # Visit the new glossary term page
    visit(new_glossary_term_path)
    assert_selector("body.glossary_terms__new")

    # Fill in the form with valid data
    unique_name = "test term #{Time.now.to_i}"
    fill_in("glossary_term_name", with: unique_name)
    fill_in("glossary_term_description", with: "A test description")

    # Scope click to the glossary terms form (not the logout button!)
    within("form[action='/glossary_terms']") do
      click_commit
    end

    # Verify successful creation
    assert_selector("body.glossary_terms__show")

    # Verify database effect
    term = GlossaryTerm.find_by(name: unique_name)
    assert(term, "Glossary term should have been created")
    assert_equal("A test description", term.description)
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

    # Scope click to the correct form
    within("form[action='#{glossary_term_path(term)}']") do
      click_commit
    end

    # Verify successful update
    assert_selector("body.glossary_terms__show")

    # Verify database effect
    term.reload
    assert_equal("Updated description for testing", term.description)
  end
end
