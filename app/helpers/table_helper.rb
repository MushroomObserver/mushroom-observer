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

  # <th> are cells analogous to <td>, not <tr>
  def make_col_headers(args)
    tag.tr(**args[:row_opts]) do
      if args[:headers].is_a?(Array)
        th_args = args.deep_dup
        th_args[:cell_opts] = th_args[:cell_opts].merge({ scope: "col" })

        args[:headers].map do |header|
          make_th(header, th_args)
        end.safe_join
      else
        args[:headers] # if a precomposed string, print as is (?)
      end
    end
  end

  def make_th(header, args)
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
            make_th(cell, th_args)
          else
            make_td(cell, args)
          end
        end.safe_join
      else
        row # if the row is a string, we're not going to force row headers
      end
    end
  end

  def make_td(cell, args)
    tag.td(**args[:cell_opts]) { cell.to_s }
  end

  def violation_rows(project, violations)
    violations.each_with_object([]) do |obs, rows|
      rows << ["",
               displayed_obs_when(project, obs),
               obs.lat,
               obs.long,
               obs.where,
               link_to_object(obs, obs.text_name) + " (#{obs.id})",
               obs.user.name]
    end
  end

  def displayed_obs_when(project, obs)
    if project.violates_date_range?(obs)
      tag.span(obs.when, class: "violation-highlight")
    else
      obs.when
    end
  end

  def displayed_obs_lat(project, obs)
  end

  def displayed_obs_lon(project, obs)
  end

  def displayed_obs_where(project, obs)
  end
end
