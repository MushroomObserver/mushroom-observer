# frozen_string_literal: true

require("test_helper")

class Title::SpeciesListTest < UnitTestCase
  def test_page_title_and_document_title
    spl = species_lists(:first_species_list)
    title = Title.for(spl)

    assert_equal(spl.title, title.page_title)
    assert_equal(spl.title, title.document_title)
  end
end
