# frozen_string_literal: true

require("test_helper")

class Title::VisualGroupTest < UnitTestCase
  def test_page_title_and_document_title
    vg = visual_groups(:visual_group_one)
    title = Title.for(vg)

    assert_equal(vg.name, title.page_title)
    assert_equal(vg.name, title.document_title)
  end
end
