# frozen_string_literal: true

require("test_helper")

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

  def test_make_table
    expect = "<table><tr><td>1</td><td>2</td></tr>" \
             "<tr><td>3</td><td>4</td></tr></table>"
    table = make_table([[1, 2], [3, 4]])
    assert_equal(expect, table)
  end

  def test_make_table_with_colspan
    expect = '<table><tr colspan="2"><td>5</td><td>6</td></tr></table>'
    table = make_table([[5, 6]], {}, { colspan: 2 })
    assert_equal(expect, table)
  end

  def test_make_table_row_without_columns
    expect = "<table><tr>row without columns</tr></table>"
    table = make_table(["row without columns"])
    assert_equal(expect, table)
  end
end
