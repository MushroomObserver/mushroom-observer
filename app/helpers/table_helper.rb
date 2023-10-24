# frozen_string_literal: true

#  make_table                   # make table from list of arrays

module TableHelper
  # Create a table out of a list of Arrays.
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
  def make_table(rows, table_opts = {}, tr_opts = {}, td_opts = {})
    tag.table(table_opts) do
      rows.map do |row|
        make_row(row, tr_opts, td_opts) + make_line(row, td_opts)
      end.safe_join
    end
  end

  def make_row(row, tr_opts = {}, td_opts = {})
    content_tag(:tr, tr_opts) do
      if row.is_a?(Array)
        row.map do |cell|
          make_cell(cell, td_opts)
        end.safe_join
      else
        row
      end
    end
  end

  def make_cell(cell, td_opts = {})
    tag.td(cell.to_s, td_opts)
  end

  def make_line(_row, td_opts)
    colspan = td_opts[:colspan]
    if colspan
      tag.tr(class: "MatrixLine") do
        tag.td(tag.hr, class: "MatrixLine", colspan: colspan)
      end
    else
      safe_empty
    end
  end
end
