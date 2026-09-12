# frozen_string_literal: true

require("test_helper")

class Title::UserTest < UnitTestCase
  def test_page_title_and_document_title
    user = users(:rolf)
    title = Title.for(user)
    expected = :show_user_about.t(user: user.unique_text_name)

    assert_equal(expected, title.page_title)
    assert_equal(expected, title.document_title)
  end
end
