# frozen_string_literal: true

require("test_helper")

# test the table helpers
class TableHelperTest < ActionView::TestCase
  include ContentHelper

  def test_make_table
    expect = "<table class=\"table\"><tr><td>1</td><td>2</td></tr>" \
             "<tr><td>3</td><td>4</td></tr></table>"
    table = make_table(rows: [[1, 2], [3, 4]])
    assert_equal(expect, table)
  end

  def test_make_table_with_colspan
    expect = "<table class=\"table\"><tr colspan=\"2\"><td>5</td><td>6</td>" \
             "</tr></table>"
    table = make_table(rows: [[5, 6]], row_opts: { colspan: 2 })
    assert_equal(expect, table)
  end

  def test_make_table_row_without_columns
    expect = "<table class=\"table\"><tr>row without columns</tr></table>"
    table = make_table(rows: ["row without columns"])
    assert_equal(expect, table)
  end
end
