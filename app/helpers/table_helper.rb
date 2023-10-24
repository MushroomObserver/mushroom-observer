# frozen_string_literal: true

#  make_table                   # make table from list of arrays

module TableHelper
  # Create a table out of a list of Arrays and HTML options.
  #
  #   make_table([[1,2],[3,4]])
  #
  # Produces:
  #
  #   <table>
  #     <tr>
  #       <td>1</td>
  #       <td>2</td>
  #     </tr>
  #     <tr>
  #       <td>3</td>
  #       <td>4</td>
  #     </tr>
  #   </table>
  #
  # args: header, rows, table_opts, header_opts, row_opts, cell_opts

  def make_table(**args)
    args = default_table_args(args)
    table_opts = default_table_opts(args[:table_opts])

    tag.table(**table_opts) do
      if args[:header].present?
        concat(make_header(args[:header], args[:header_opts], args[:cell_opts]))
      end
      if args[:rows].present?
        args[:rows].map do |row|
          concat([
            make_row(row, args[:row_opts], args[:cell_opts]),
            make_line(args[:cell_opts])
          ].safe_join)
        end
      end
    end
  end

  # Add the default bootstrap `table` CSS class without stomping other classes
  def default_table_opts(table_opts = {})
    table_opts[:class] = class_names(table_opts[:class], "table")
    table_opts
  end

  # table_opts defaults added above
  def default_table_args(args)
    {
      header: [],
      rows: [],
      table_opts: {},
      header_opts: {},
      row_opts: {},
      cell_opts: {}
    }.merge(args)
  end

  def make_header(header, header_opts, cell_opts)
    tag.th(**header_opts) do
      if header.is_a?(Array)
        header.map do |cell|
          make_cell(cell, cell_opts)
        end.safe_join
      else
        header
      end
    end
  end

  def make_row(row, row_opts, cell_opts)
    tag.tr(**row_opts) do
      if row.is_a?(Array)
        row.map do |cell|
          make_cell(cell, cell_opts)
        end.safe_join
      else
        row
      end
    end
  end

  def make_cell(cell, cell_opts)
    tag.td(**cell_opts) { cell.to_s }
  end

  # ?
  def make_line(cell_opts)
    colspan = cell_opts[:colspan]
    if colspan
      tag.tr(class: "MatrixLine") do
        tag.td(tag.hr, class: "MatrixLine", colspan: colspan)
      end
    else
      safe_empty
    end
  end
end
