# frozen_string_literal: true

require("test_helper")

class Title::ProjectTest < UnitTestCase
  def test_page_title_and_document_title
    project = projects(:eol_project)
    title = Title.for(project)

    assert_equal(project.title, title.page_title)
    assert_equal(project.title, title.document_title)
  end
end
