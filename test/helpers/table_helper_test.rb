# frozen_string_literal: true

require("test_helper")

# test the table helpers
class TableHelperTest < ActionView::TestCase
  include ContentHelper

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
