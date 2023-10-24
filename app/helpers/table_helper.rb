# frozen_string_literal: true

#  make_table                   # make table from list of arrays

module TableHelper
  # Create a table out of Arrays and HTML options.
  #
  #   make_table(
  #     header: ["This", "That"],
  #     rows: [[1,2],[3,4]]),
  #     table_opts: { class: "table-striped" },
  #     cell_opts: { class: "mr-4" }
  #   )
  #
  # Produces:
  #
  #   <table class="table table-striped">
  #     <tr>
  #       <th class="mr-4">This</td>
  #       <th class="mr-4">That</td>
  #     </tr>
  #     <tr>
  #       <td class="mr-4">1</td>
  #       <td class="mr-4">2</td>
  #     </tr>
  #     <tr>
  #       <td class="mr-4">3</td>
  #       <td class="mr-4">4</td>
  #     </tr>
  #   </table>
  #
  # args: header, rows, table_opts, header_opts, row_opts, cell_opts
  #       row_headers (bool)

  def make_table(**args)
    args = default_table_args(args)
    table_opts = default_table_opts(args[:table_opts])

    tag.table(**table_opts) do
      concat(make_col_headers(args)) if args[:headers].present?

      if args[:rows].present?
        concat(args[:rows].map do |row|
          make_row(row, args)
        end.safe_join)
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
      headers: [],
      rows: [],
      table_opts: {},
      header_opts: {},
      row_opts: {},
      cell_opts: {},
      row_headers: false
    }.merge(args)
  end

  # note: th are like cells, not rows
  def make_col_headers(args)
    tag.tr(**args[:row_opts]) do
      if args[:headers].is_a?(Array)
        th_args = args.deep_dup
        th_args[:cell_opts] = th_args[:cell_opts].merge({ scope: "col" })

        args[:headers].map do |header|
          make_header(header, th_args)
        end.safe_join
      else
        args[:headers] # if a precomposed string, print as is (?)
      end
    end
  end

  def make_header(header, args)
    tag.th(**args[:cell_opts]) { header.to_s }
  end

  # pass row_headers: true to get a <th scope="row"> instead of <td>
  # at the head of each row.
  def make_row(row, args)
    tag.tr(**args[:row_opts]) do
      if row.is_a?(Array)
        # don't overwrite args, keep assignment out of loop
        th_args = args.deep_dup
        th_args[:cell_opts] = th_args[:cell_opts].merge({ scope: "row" })

        row.map.with_index do |cell, index|
          if index.zero? && args[:row_headers] == true
            make_header(cell, th_args)
          else
            make_cell(cell, args)
          end
        end.safe_join
      else
        row # if the row is a string, we're not going to force row headers
      end
    end
  end

  def make_cell(cell, args)
    tag.td(**args[:cell_opts]) { cell.to_s }
  end

  # ?
  # def make_line(cell_opts)
  #   colspan = cell_opts[:colspan]
  #   if colspan
  #     tag.tr(class: "MatrixLine") do
  #       tag.td(tag.hr, class: "MatrixLine", colspan: colspan)
  #     end
  #   else
  #     safe_empty
  #   end
  # end
end
