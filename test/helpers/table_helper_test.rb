# frozen_string_literal: true

require("test_helper")

# test the table helpers.
class TableHelperTest < ActionView::TestCase
  include ContentHelper

  def test_make_table
    expect = "<table class=\"table\">" \
             "<tr><td>1</td><td>2</td></tr>" \
             "<tr><td>3</td><td>4</td></tr>" \
             "</table>"
    table = make_table(rows: [[1, 2], [3, 4]])
    assert_equal(expect, table)
  end

  def test_make_table_with_table_opts
    expect = "<table class=\"yama table\">" \
             "<tr><td>1</td><td>2</td></tr>" \
             "<tr><td>3</td><td>4</td></tr>" \
             "</table>"
    table = make_table(table_opts: { class: "yama" }, rows: [[1, 2], [3, 4]])
    assert_equal(expect, table)
  end

  def test_make_table_with_row_opts
    expect = "<table class=\"table\">" \
             "<tr colspan=\"2\"><td>5</td><td>6</td></tr>" \
             "</table>"
    table = make_table(rows: [[5, 6]], row_opts: { colspan: 2 })
    assert_equal(expect, table)
  end

  def test_make_table_with_cell_opts
    expect = "<table class=\"table\">" \
             "<tr><td class=\"hi\">5</td><td class=\"hi\">6</td></tr>" \
             "</table>"
    table = make_table(rows: [[5, 6]], cell_opts: { class: "hi" })
    assert_equal(expect, table)
  end

  def test_make_table_row_without_columns
    expect = "<table class=\"table\"><tr>row without columns</tr></table>"
    table = make_table(rows: ["row without columns"])
    assert_equal(expect, table)
  end

  def test_make_table_with_col_headers
    expect = "<table class=\"table\">" \
             "<tr><th scope=\"col\">This</th><th scope=\"col\">That</th></tr>" \
             "<tr><td>1</td><td>2</td></tr>" \
             "<tr><td>3</td><td>4</td></tr>" \
             "</table>"
    table = make_table(headers: %w[This That], rows: [[1, 2], [3, 4]])
    assert_equal(expect, table)
  end

  def test_make_table_with_col_and_row_headers
    expect = "<table class=\"table\">" \
             "<tr><th scope=\"col\">This</th><th scope=\"col\">That</th></tr>" \
             "<tr><th scope=\"row\">1</th><td>2</td></tr>" \
             "<tr><th scope=\"row\">3</th><td>4</td></tr>" \
             "</table>"
    table = make_table(headers: %w[This That], rows: [[1, 2], [3, 4]],
                       row_headers: true)
    assert_equal(expect, table)
  end
end
