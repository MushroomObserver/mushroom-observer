# frozen_string_literal: true

require("test_helper")

# test the application-wide helpers
module Header
  class TitleHelperTest < ActionView::TestCase
    include LinkHelper

    def test_title_tag_contents
      # Prove that if title is present, <title> contents are @title
      title = "title present"
      action_name = "something_else"
      assert_equal(title, title_tag_contents(title, action: action_name))

      # Prove that if title is absent,
      # then <title> contents are action_name humanized
      title = ""
      action_name = "blah_blah"
      assert_equal("Blah Blah", title_tag_contents(title, action: action_name))
    end
  end
end
