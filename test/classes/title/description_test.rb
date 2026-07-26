# frozen_string_literal: true

require("test_helper")

# Description is abstract -- NameDescription/LocationDescription are
# the concrete subclasses that actually get titled. Both must dispatch
# to Title::Description via Title.for's class-hierarchy walk.
class Title::DescriptionTest < UnitTestCase
  def test_page_title_and_document_title_for_name_description
    desc = name_descriptions(:agaricus_campestras_desc)
    title = Title.for(desc)

    assert_instance_of(Title::Description, title)
    assert_equal(desc.format_name.t, title.page_title)
    assert_equal(desc.text_name, title.document_title)
  end

  def test_page_title_and_document_title_for_location_description
    desc = location_descriptions(:albion_desc)
    title = Title.for(desc)

    assert_instance_of(Title::Description, title)
    assert_equal(desc.format_name.t, title.page_title)
    assert_equal(desc.text_name, title.document_title)
  end
end
