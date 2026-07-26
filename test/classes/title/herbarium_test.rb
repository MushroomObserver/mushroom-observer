# frozen_string_literal: true

require("test_helper")

class Title::HerbariumTest < UnitTestCase
  def test_page_title
    herb = herbaria(:nybg_herbarium)

    assert_equal(herb.format_name.t, Title.for(herb).page_title)
  end

  def test_document_title
    herb = herbaria(:nybg_herbarium)

    assert_equal(herb.format_name, Title.for(herb).document_title)
  end
end
