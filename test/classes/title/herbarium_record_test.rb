# frozen_string_literal: true

require("test_helper")

class Title::HerbariumRecordTest < UnitTestCase
  def test_page_title
    rec = herbarium_records(:interesting_unknown)

    assert_equal(rec.herbarium_label.t, Title.for(rec).page_title)
  end

  def test_document_title
    rec = herbarium_records(:interesting_unknown)

    assert_equal(rec.herbarium_label, Title.for(rec).document_title)
  end
end
