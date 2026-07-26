# frozen_string_literal: true

require("test_helper")

class Title::NameTest < UnitTestCase
  def test_page_title
    name = names(:agaricus_campestris)

    assert_equal(name.display_name(nil).t.small_author,
                 Title.for(name).page_title)
  end

  def test_page_title_respects_user_hide_authors_pref
    name = names(:agaricus_campestris)
    user = users(:rolf)

    assert_equal(name.display_name(user).t.small_author,
                 Title.for(name).page_title(user))
  end

  def test_document_title
    name = names(:agaricus_campestris)

    assert_equal(name.text_name, Title.for(name).document_title)
  end
end
