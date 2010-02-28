#
#  = HTML Helpers
#
#  lnbsp::                 Replace ' ' with '&nbsp;'.
#  indent::                Create whitespace of the given width.
#  add_context_help::      Wrap string in '<acronym>' tag.
#  make_table::            Create table from list of Arrays.
#  add_header::            Add random string to '<head>' section.
#  calc_color::            Calculate background color in alternating list.
#  colored_notes_box::     Create a div for notes in Description subclasses.
#  boxify::                Wrap HTML in colored-outline box.
#  end_boxify::            End boxify box.
#
################################################################################

module ApplicationHelper::HTML

  # Replace spaces with '&nbsp;'.
  #
  #   <%= button_name.lnbsp %>
  def lnbsp(key)
    key.l.gsub(' ', '&nbsp;')
  end

  # Create an in-line white-space element approximately the given width in
  # pixels.  It should be non-line-breakable, too.
  def indent(w=10)
   "<span style='margin-left:#{w}px'>&nbsp;</span>"
  end

  # Wrap an html object in '<acronym>' tag.  This has the effect of giving it
  # context help (mouse-over popup) in most modern browsers.
  #
  #   <%= add_context_help(link, "Click here to do something.") %>
  def add_context_help(object, help)
    tag('acronym', { :title => help }, true) + object + '</acronym>'
  end

  # Create a table out of a list of Arrays.
  #
  #   make_table( [1,2], [3,4] )
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
  def make_table(*rows)
    '<table>' + rows.map do |row|
      '<tr>' + row.map do |cell|
        '<td>' + h(cell) + '</td>'
      end.join + '</tr>'
    end.join + '</table>'
  end

  # Add something to the header from within view.  This can be called as many
  # times as necessary -- the application layout will mash them all together
  # and stick them at the end of the <tt>&gt;head&lt;/tt> section.
  #
  #   <%
  #     add_header(GMap.header)       # adds GMap general header
  #     gmap = make_map(@locations)
  #     add_header(finish_map(gmap))  # adds map-specific header
  #   %>
  #
  def add_header(str)
    @header ||= ''
    @header += str
  end

  # Decide what the color should be for a list item.  Returns 0 or 1.
  # row::       row number
  # col::       column number
  # alt_rows::  from layout_params['alternate_rows']
  # alt_cols::  from layout_params['alternate_columns']
  #
  # (See also ApplicationController#calc_layout_params.)
  #
  def calc_color(row, col, alt_rows, alt_cols)
    color = 0
    if alt_rows
      color = row % 2
    end
    if alt_cols
      if (col % 2) == 1
        color = 1 - color
      end
    end
    color
  end

  # Create a div for notes in Description subclasses.
  #
  #   <%= colored_box(even_or_odd, html) %>
  #
  #   <% colored_box(even_or_odd) do %>
  #     Render stuff in here.  Note lack of "=" in line above.
  #   <% end %>
  #
  def colored_notes_box(even, msg=nil, &block)
    msg = capture(&block) if block_given?
    klass = "ListLine#{even ? 0 : 1}"
    style = [
      'margin-left:10px',
      'margin-right:10px',
      'padding:10px',
      'border:1px dotted',
    ].join(';')
    msg = "<div class='#{klass}' style='#{style}'>
      #{msg}
    </div>"
    if block_given?
      concat(msg, block.binding)
    else
      msg
    end
  end

  # Wrap some HTML in the cute red/yellow/green box used for +flash[:notice]+.
  #
  #   <%= boxify(2, flash[:notice]) %>
  #
  #   <% boxify(1) do %>
  #     Render more stuff in here.  Note lack of "=" in line above.
  #   <% end %>
  #
  # Notice levels are:
  # 0:: notice (green)
  # 1:: warning (yellow)
  # 2:: error (red)
  #
  def boxify(lvl=0, msg=nil, &block)
    type = "Notices"
    type = "Warnings" if lvl == 1
    type = "Errors"   if lvl == 2
    msg = capture(&block) if block_given?
    msg = "<div style='width:500px'>
      <table class='#{type}'><tr><td>
        #{msg}
      </td></tr></table>
    </div>"
    if block_given?
      concat(msg, block.binding)
    else
      msg
    end
  end
end
