# frozen_string_literal: true

require("test_helper")

class TableTest < ComponentTestCase
  # Simple test struct for table rows
  TestRow = Struct.new(:name, :age, :url, keyword_init: true)

  def test_renders_table_with_columns
    rows = [
      TestRow.new(name: "Alice", age: 30),
      TestRow.new(name: "Bob", age: 25)
    ]

    html = render(Components::Table.new(rows)) do |t|
      t.column("Name", &:name)
      t.column("Age", &:age)
    end

    # Table structure
    assert_html(html, "table.table")
    assert_html(html, "thead")
    assert_html(html, "tbody")

    # Headers
    assert_includes(html, "<th>Name</th>")
    assert_includes(html, "<th>Age</th>")

    # Data rows
    assert_includes(html, "<td>Alice</td>")
    assert_includes(html, "<td>30</td>")
    assert_includes(html, "<td>Bob</td>")
    assert_includes(html, "<td>25</td>")
  end

  def test_renders_empty_table_with_no_rows
    rows = []

    html = render(Components::Table.new(rows)) do |t|
      t.column("Name", &:name)
    end

    assert_html(html, "table.table")
    assert_html(html, "thead")
    assert_html(html, "th", text: "Name")
    assert_html(html, "tbody")
    # No td elements since no rows
    assert_no_match(/<td>/, html)
  end

  def test_accepts_custom_class
    rows = [TestRow.new(name: "Test")]

    html = render(Components::Table.new(rows,
                                        class: "table-sm table-striped")) do |t|
      t.column("Name", &:name)
    end

    assert_html(html, "table.table.table-sm.table-striped")
  end

  def test_accepts_custom_id
    rows = [TestRow.new(name: "Test")]

    html = render(Components::Table.new(rows, id: "my-table")) do |t|
      t.column("Name", &:name)
    end

    assert_html(html, "table#my-table")
  end

  def test_column_returns_nil
    rows = []
    table = Components::Table.new(rows)

    # column should return nil to prevent ERB output issues
    result = table.column("Header") { |_row| "content" }
    assert_nil(result)
  end

  def test_works_with_activerecord_objects
    user_list = [users(:rolf), users(:mary)]

    html = render(Components::Table.new(user_list)) do |t|
      t.column("Login", &:login)
    end

    assert_html(html, "table.table")
    # Both users should appear in the table
    assert_includes(html, "rolf")
    assert_includes(html, "mary")
  end

  def test_column_content_can_include_html
    rows = [TestRow.new(name: "Alice", url: "/users/1")]

    html = render(Components::Table.new(rows)) do |t|
      t.column("Name") do |row|
        view_context.link_to(row.name, row.url)
      end
    end

    assert_html(html, "td a[href='/users/1']", text: "Alice")
  end

  def test_headers_false_skips_thead
    rows = [TestRow.new(name: "Alice")]

    html = render(Components::Table.new(rows, headers: false)) do |t|
      t.column("Name", &:name)
    end

    assert_html(html, "table.table")
    assert_html(html, "tbody")
    assert_includes(html, "<td>Alice</td>")
    # Should NOT have thead
    assert_no_match(/<thead>/, html)
    assert_no_match(/<th>/, html)
  end
end
