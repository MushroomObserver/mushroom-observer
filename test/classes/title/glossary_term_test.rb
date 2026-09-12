# frozen_string_literal: true

require("test_helper")

class Title::GlossaryTermTest < UnitTestCase
  def test_page_title_and_document_title
    term = glossary_terms(:conic_glossary_term)
    title = Title.for(term)

    assert_equal(term.name, title.page_title)
    assert_equal(term.name, title.document_title)
  end
end
