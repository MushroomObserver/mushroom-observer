# frozen_string_literal: true

require("test_helper")

class Title::ImageTest < UnitTestCase
  def test_page_title
    img = images(:in_situ_image)

    assert_equal(img.format_name.t.small_author, Title.for(img).page_title)
  end

  def test_document_title
    img = images(:in_situ_image)

    assert_equal(img.title_subjects(:text_name).presence || :image.l,
                 Title.for(img).document_title)
  end

  def test_document_title_falls_back_to_image_tag
    img = Image.new

    assert_equal(:image.l, Title.for(img).document_title)
  end
end
