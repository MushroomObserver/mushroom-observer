# frozen_string_literal: true

# Table component for rendering data tables with Bootstrap styling.
#
# Three body modes:
#
# - **Column mode** (default): caller defines columns via
#   `t.column(header) { |row| cell_content }`. Table iterates
#   `rows`, emitting one `<tr>` per row with one `<td>` per column.
#   Per-column `class:` and arbitrary HTML attrs (`width:`, etc.)
#   land on both the `<th>` and `<td>` for that column.
#
# - **Row mode**: caller defines columns for the header only via
#   `t.column(header)` (no content block), then provides a single
#   `t.row { |row, idx| ... }` block that renders the entire `<tr>`
#   for each row. Use this when each `<tr>` needs its own data attrs
#   (Stimulus root, Superform `namespace(idx)` wrapping, etc.) —
#   i.e. the row IS a Phlex component that emits its own
#   `<tr id="..." data-controller="...">`.
#
# - **Body mode**: caller passes `t.body { ... }` to render the
#   entire `<tbody>` children themselves. Use this when the table
#   isn't really "rows of data" being iterated — e.g. a Stimulus-
#   rooted layout shell with mixed-shape rows. `rows` arg is
#   unused / can be nil in this mode.
#
# Table-level HTML attrs (`data:`, `cols:`, ARIA attrs, etc.) go in
# the `attributes:` Hash. `class:` and `id:` are first-class init
# args.
#
# @example Column mode (uniform rows)
#   render(Components::Table.new(@users)) do |t|
#     t.column("Name") { |user| user.name }
#     t.column("Email") { |user| user.email }
#   end
#
# @example Column mode with per-column attrs
#   render(Components::Table.new(@users)) do |t|
#     t.column("Name", width: "33%") { |user| user.name }
#     t.column("Actions", class: "text-right") { |u| destroy_button(u) }
#   end
#
# @example Row mode (Stimulus-rooted rows)
#   render(Components::Table.new(@trackers,
#                                tbody_id: "field_slip_job_trackers")) do |t|
#     t.column(:FILENAME.t)
#     t.column(:STATUS.t, class: "text-right")
#     t.row { |tracker| render(TrackerRow.new(tracker: tracker, user: @user)) }
#   end
#
# @example Body mode (table-level data attrs + mixed rows)
#   render(Components::Table.new(
#     class: "name-lister",
#     attributes: { data: { controller: "name-list" } }
#   )) do |t|
#     t.column(:NAME.t, width: "20%")
#     t.column(:OPTIONS.t, width: "80%")
#     t.body do
#       tr { td { scroller(:names) }; td { scroller(:options) } }
#       tr { td(colspan: "2") { render(Form.new(...)) } }
#     end
#   end
class Components::Table < Components::Base
  # @param rows [Enumerable, nil] rows passed to each column/row
  #   block (unused in body mode)
  # @param class [String] CSS classes appended to the default "table"
  # @param id [String] `id=` for the `<table>` element
  # @param show_headers [Boolean] render the `<thead>` (default true)
  # @param tbody_id [String] `id=` for the `<tbody>` element (use to
  #   make the tbody a Turbo Stream target)
  # @param attributes [Hash] arbitrary HTML attrs forwarded to the
  #   `<table>` element (`data:`, `cols:`, ARIA attrs, etc.)
  def initialize(rows = nil, class: nil, id: nil, show_headers: true, # rubocop:disable Metrics/ParameterLists
                 tbody_id: nil, attributes: {})
    super()
    @rows = rows
    @columns = []
    @row_block = nil
    @body_block = nil
    @heading_block = nil
    @heading_attrs = {}
    @show_headers = show_headers
    @tbody_id = tbody_id
    @html_class = binding.local_variable_get(:class)
    @html_id = id
    @attributes = attributes
  end

  def view_template(&block)
    # Capture column/row/body definitions without outputting anything.
    # Uses Phlex's `vanish` pattern for tables:
    # https://www.phlex.fun/components/yielding.html#vanishing-the-yield
    vanish(&block)

    table(**table_attributes) do
      render_thead if @show_headers
      render_tbody
    end
  end

  # Define a column. In column mode, the block is called for each
  # row to produce the cell content. In row / body mode, the block
  # is ignored — only the `header` and per-column attrs are used,
  # and the caller's `row` / `body` block emits the cells.
  #
  # @param header [String] the column header text
  # @param class [String] CSS class for the th/td elements
  # @param attributes [Hash] arbitrary HTML attrs (e.g. `width: "33%"`,
  #   `data: { foo: "bar" }`) forwarded to both the `<th>` and `<td>`
  #   elements for this column
  # @yield [row] block that receives each row and returns cell content
  # @return [nil] returns nil to prevent ERB output
  def column(header, class: nil, **attributes, &content)
    klass = binding.local_variable_get(:class)
    attrs = attributes.dup
    attrs[:class] = klass if klass
    @columns << { header: header, attributes: attrs, content: content }
    nil
  end

  # Register a row block for row mode. When set, Table renders the
  # `<thead>` and `<tbody>` chrome but delegates each `<tr>` to the
  # block. The block runs in the caller's closure, so anything in
  # scope where the Table is rendered (the surrounding form's
  # `namespace`, the caller's ivars, etc.) is callable inside the
  # block.
  #
  # @yield [row, idx] block that renders one `<tr>` per row
  # @return [nil]
  def row(&block)
    @row_block = block
    nil
  end

  # Register a body block for body mode. When set, Table renders the
  # `<thead>` chrome and a single `<tbody>` wrapper, but the entire
  # `<tbody>` children are rendered by the caller's block — Table
  # does NOT iterate `rows`. Use for "this isn't really rows of
  # data" cases (table-level Stimulus root with mixed-shape rows,
  # layout shells, etc.).
  #
  # @yield block that renders the tbody children
  # @return [nil]
  def body(&block)
    @body_block = block
    nil
  end

  # Register a section heading row — a single `<th>` with
  # `colspan` = number of columns, rendered inside the `<thead>`
  # instead of the standard per-column header row. Use for tables
  # whose header is a label ("Curators:", "Recent activity:", etc.)
  # rather than per-column titles.
  #
  # When `heading` is set, the per-column `header:` text on each
  # `column(...)` is ignored — only the heading row is emitted in
  # `<thead>`. `show_headers: false` still suppresses the `<thead>`
  # entirely; pass `show_headers: true` (the default) for the
  # heading to render.
  #
  # @param attributes [Hash] arbitrary HTML attrs forwarded to the
  #   heading `<th>` (`class:`, `data:`, etc.)
  # @yield block that renders the heading cell content
  # @return [nil]
  def heading(**attributes, &block)
    @heading_block = block
    @heading_attrs = attributes
    nil
  end

  private

  def table_attributes
    base_class = "table"
    combined_class =
      @html_class ? "#{base_class} #{@html_class}" : base_class
    attrs = @attributes.dup
    attrs[:class] = combined_class
    attrs[:id] = @html_id if @html_id
    attrs
  end

  def render_thead
    thead do
      if @heading_block
        render_heading_row
      else
        render_column_header_row
      end
    end
  end

  def render_heading_row
    tr do
      th(colspan: @columns.length, **@heading_attrs, &@heading_block)
    end
  end

  def render_column_header_row
    tr do
      @columns.each do |column|
        th(**column[:attributes]) { column[:header] }
      end
    end
  end

  def render_tbody
    tbody(id: @tbody_id) do
      if @body_block
        @body_block.call
      elsif @row_block
        @rows.each.with_index { |row, idx| @row_block.call(row, idx) }
      else
        @rows.each { |row| render_default_row(row) }
      end
    end
  end

  def render_default_row(row)
    tr do
      @columns.each do |column|
        td(**column[:attributes]) { column[:content].call(row) }
      end
    end
  end
end
