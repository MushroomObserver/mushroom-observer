# frozen_string_literal: true

require("test_helper")

class TableTest < ComponentTestCase
  # Simple test struct for table rows
  TestRow = Struct.new(:name, :age, :url)

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

  def test_per_column_class_lands_on_both_th_and_td
    rows = [TestRow.new(name: "Alice")]

    html = render(Components::Table.new(rows)) do |t|
      t.column("Name", class: "text-right", &:name)
    end

    assert_html(html, "thead th.text-right", text: "Name")
    assert_html(html, "tbody td.text-right", text: "Alice")
  end

  def test_per_column_arbitrary_attrs_forwarded_to_th_and_td
    rows = [TestRow.new(name: "Alice")]

    html = render(Components::Table.new(rows)) do |t|
      t.column("Name", width: "33%", data: { x: "v" }, &:name)
    end

    # `width:` and `data:` from the caller arrive on both elements.
    assert_html(html, "thead th[width='33%'][data-x='v']", text: "Name")
    assert_html(html, "tbody td[width='33%'][data-x='v']", text: "Alice")
  end

  def test_tbody_id_for_turbo_stream_targeting
    rows = [TestRow.new(name: "Alice")]

    html = render(Components::Table.new(rows,
                                        tbody_id: "users_tbody")) do |t|
      t.column("Name", &:name)
    end

    assert_html(html, "tbody#users_tbody")
  end

  def test_table_attributes_hash_lands_on_table_element
    rows = [TestRow.new(name: "Alice")]

    html = render(Components::Table.new(
                    rows,
                    attributes: { cols: "1",
                                  data: { controller: "name-list" } }
                  )) do |t|
      t.column("Name", &:name)
    end

    # `attributes:` Hash forwards arbitrary HTML attrs to the
    # `<table>` element (table-level Stimulus root etc.).
    assert_html(html, "table[cols='1'][data-controller='name-list']")
  end

  def test_body_mode_caller_renders_entire_tbody_children
    # Body mode: caller emits the whole tbody body — no per-row
    # iteration. Use this when the table isn't really "rows of data"
    # (mixed-shape rows, layout shells, etc.).
    html = render(BodyModeTestHost.new)

    # Headers from `column(...)` still render.
    assert_includes(html, "<th>First</th>")
    assert_includes(html, "<th>Second</th>")
    # tbody contains exactly the markup the body block emitted —
    # two `<tr>` of different shapes (3-col + colspan).
    assert_html(html, "tbody tr td", text: "left")
    assert_html(html, "tbody tr td[colspan='2']", text: "footer")
  end

  def test_row_mode_delegates_each_tr_to_block
    # Row mode: the column block is ignored — only the header is
    # used from `column(...)`. The `row { |row, idx| ... }` block
    # emits the whole `<tr>` (and its cells / data attrs / etc.).
    html = render(RowModeTestHost.new(rows: [
                                        TestRow.new(name: "Alice"),
                                        TestRow.new(name: "Bob")
                                      ]))

    # Headers still come from `column(...)`.
    assert_html(html, "thead th", text: "Name")
    # Caller-rendered `<tr>` with per-row id + data attr.
    assert_html(html, "tr#row_0[data-name='Alice'] td", text: "ALICE")
    assert_html(html, "tr#row_1[data-name='Bob'] td", text: "BOB")
  end

  def test_headers_false_skips_thead
    rows = [TestRow.new(name: "Alice")]

    html = render(Components::Table.new(rows, show_headers: false)) do |t|
      t.column("Name", &:name)
    end

    assert_html(html, "table.table")
    assert_html(html, "tbody")
    assert_includes(html, "<td>Alice</td>")
    # Should NOT have thead
    assert_no_match(/<thead>/, html)
    assert_no_match(/<th>/, html)
  end

  # --- Section heading row (t.heading) -----------------------------

  def test_heading_renders_single_th_with_colspan_equal_column_count
    rows = [TestRow.new(name: "Alice")]

    # Block return values become the cell content — production
    # callers use Phlex `plain` / `trusted_html` etc. inside the
    # block because the block runs in Phlex view context there.
    html = render(Components::Table.new(rows)) do |t|
      t.heading { "Section label:" }
      t.column("Name", &:name)
      t.column("Age", &:age)
    end

    # Single th with colspan = number of columns.
    assert_html(html, "thead tr th[colspan='2']", text: "Section label:")
    # Per-column header row is suppressed when heading is set.
    assert_html(html, "thead tr", count: 1)
    assert_no_match(%r{<th>Name</th>}, html)
    assert_no_match(%r{<th>Age</th>}, html)
    # Body still renders normally.
    assert_includes(html, "<td>Alice</td>")
  end

  def test_heading_forwards_attributes_to_th
    rows = []

    html = render(Components::Table.new(rows)) do |t|
      t.heading(class: "text-center", data: { foo: "bar" }) { "Curators:" }
      t.column("a", &:name)
      t.column("b", &:name)
    end

    assert_html(html,
                "thead th[colspan='2'][class='text-center'][data-foo='bar']",
                text: "Curators:")
  end

  def test_heading_with_show_headers_false_renders_no_thead
    rows = [TestRow.new(name: "Alice")]

    html = render(Components::Table.new(rows, show_headers: false)) do |t|
      t.heading { "Suppressed:" }
      t.column("Name", &:name)
    end

    # `show_headers: false` overrides the heading — no thead at all.
    assert_no_match(/<thead>/, html)
    assert_no_match(/Suppressed:/, html)
    # Body still renders.
    assert_includes(html, "<td>Alice</td>")
  end
end

# Test host for body mode: renders Table inside a real Phlex view so
# the body block's `self` is a Phlex component (matches how the body
# block runs in real callers like `species_lists/name_lists/new.rb`).
class BodyModeTestHost < Components::Base
  def view_template
    render(Components::Table.new) do |t|
      t.column("First")
      t.column("Second")
      t.body do
        tr do
          td { plain("left") }
          td { plain("right") }
        end
        tr do
          td(colspan: "2") { plain("footer") }
        end
      end
    end
  end
end

# Test host for row-mode: renders Table inside a real Phlex view so
# the row block's `self` is a Phlex component and `tr` / `td` resolve
# to the buffer the Table is writing to (matches how the row block
# runs in real callers like `Views::Controllers::Projects::FieldSlips::New`).
class RowModeTestHost < Components::Base
  def initialize(rows:)
    super()
    @rows = rows
  end

  def view_template
    render(Components::Table.new(@rows)) do |t|
      t.column("Name")
      t.row do |row, idx|
        tr(id: "row_#{idx}", data: { name: row.name }) do
          td { plain(row.name.upcase) }
        end
      end
    end
  end
end
