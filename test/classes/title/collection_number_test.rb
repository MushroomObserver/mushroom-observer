# frozen_string_literal: true

require("test_helper")

class Title::CollectionNumberTest < UnitTestCase
  def test_page_title
    cn = collection_numbers(:minimal_unknown_coll_num)

    assert_equal(cn.format_name.t, Title.for(cn).page_title)
  end

  def test_document_title
    cn = collection_numbers(:minimal_unknown_coll_num)

    assert_equal(cn.format_name, Title.for(cn).document_title)
  end
end
