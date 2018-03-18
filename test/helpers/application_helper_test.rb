require "test_helper"

# test the application-wide helpers
class ApplicationHelperTest < ActionView::TestCase
  def test_title_tag_contents
    # Prove that if @title is present, <title> contents are @title
    @title = "@title present"
    action_name = "something_else"
    assert_equal(@title,
                 title_tag_contents(action_name))

    # Prove that if @title is absent,
    # and there's an en.txt label for :title_for_action_name,
    # then <title> contents are the translation for that label
    @title = ""
    action_name = "user_search"
    assert_equal("User Search",
                 title_tag_contents(action_name))

    # Prove that if @title is absent,
    # and no en.txt label for :title_for_action_name,
    # then <title> contents are action name humanized
    @title = ""
    action_name = "blah_blah"
    assert_equal("Blah Blah",
                 title_tag_contents(action_name))
  end
end
