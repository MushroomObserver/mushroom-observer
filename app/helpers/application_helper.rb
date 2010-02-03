#
#  = Application Helpers
#
#  These methods are available to all templates in the application:
#
#  lnbsp::                 Replace ' ' with '&nbsp;'.
#  add_context_help::      Wrap string in '<acronym>' tag.
#  make_table::            Create table from list of Arrays.
#  add_header::            Add random string to '<head>' section.
#  calc_color::            Calculate background color in alternating list.
#  ---
#  where_string::          Wrap location name in '<span>' tag.
#  location_link::         Wrap location name in link to show/search it.
#  name_link::             Wrap name in link to show_show.
#  user_link::             Wrap user name in link to show_user.
#  user_list::             Render list of users.
#  project_link::          Wrap project name in link to show_project.
#  ---
#  rank_as_string::        Translate :Genus into "Genus" (localized).
#  rank_as_plural_string:: Translate :Genus into "Genera" (localized).
#  ---
#  boxify::                Wrap HTML in colored-outline box.
#  end_boxify::            End boxify box.
#
################################################################################

module ApplicationHelper
  require_dependency 'auto_complete_helper'
  require_dependency 'javascript_helper'
  require_dependency 'map_helper'
  require_dependency 'paginator_helper'
  require_dependency 'tab_helper'
  require_dependency 'textile_helper'

  include AutoComplete
  include Javascript
  include Map
  include Paginator
  include Tabs
  include Textile

  # Replace spaces with '&nbsp;'.
  #
  #   <%= button_name.lnbsp %>
  def lnbsp(key)
    key.l.gsub(' ', '&nbsp;')
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

  # Wrap location name in span: "<span>where (count)</span>"
  #
  #   Where: <%= where_string(obs.place_name) %>
  #
  def where_string(where, count=nil)
    result = sanitize(where).t
    result += " (#{count})" if count
    result = "<span class=\"Data\">#{result}</span>"
  end

  # Wrap location name in link to show_location / observations_at_where.
  #
  #   Where: <%= location_link(obs.where, obs.location_id) %>
  #
  def location_link(where, location_id, count=nil, click=false)
    if location_id
      loc = Location.find(location_id)
      link_string = where_string(loc.display_name, count)
      link_string += " [#{:app_click_for_map.t}]" if click
      result = link_to(link_string, :controller => 'location', :action => 'show_location', :id => location_id)
    else
      link_string = where_string(where, count)
      link_string += " [#{:app_search.t}]" if click
      result = link_to(link_string, :controller => 'observer', :action => 'observations_at_where', :where => where)
    end
    result
  end

  # Wrap name in link to show_name.
  #
  #   Parent: <%= name_link(name.parent) %>
  #
  def name_link(name, str=nil)
    begin
      str ||= name.display_name.t
      name_id = name.is_a?(Fixnum) ? name : name.id
      link_to(str, :controller => 'name', :action => 'show_name', :id => name_id)
    rescue
    end
  end

  # Wrap user name in link to show_user.
  #
  #   Owner:   <%= user_link(name.user) %>
  #   Authors: <%= name.authors.map(&:user_link).join(', ') %>
  #
  #   # If you don't have a full User instance handy:
  #   Modified by: <%= user_link(login, user_id) %>
  #
  def user_link(user, name=nil)
    begin
      name ||= h(user.unique_text_name)
      user_id = user.is_a?(Fixnum) ? user : user.id
      link_to(name, :controller => 'observer', :action => 'show_user', :id => user_id)
    rescue
    end
  end

  # Render a list of users on one line.  (Renders nothing if user list empty.)
  # This renders the following strings:
  #
  #   <%= user_list('Author', name.authors) %>
  #
  #   empty:           ""
  #   [bob]:           "Author: Bob<br/>"
  #   [bob,fred,mary]: "Authors: Bob, Fred, Mary<br/>"
  #
  def user_list(title, users)
    result = ''
    count = users.length
    if count > 0
      result = (count > 1 ? title.pluralize : title) + ": "
      result += users.map {|u| user_link(u, u.legal_name)}.join(', ')
      result += "<br/>"
    end
    result
  end

  # Wrap project name in link to show_project.
  #
  #   Project: <%= project_link(draft_name.project) %>
  def project_link(project, name=nil)
    begin
      name ||= sanitize(project.title).t
      link_to(name, :controller => 'project', :action => 'show_project', :id => project.id)
    rescue
    end
  end

  # Translate :Genus into "Genus" via internationalization.
  #
  #   Rank: <%= rank_as_string(name.rank) %>
  def rank_as_string(rank)
    eval(":rank_#{rank.to_s.downcase}.l")
  end

  # Convert :Genus to "Genera" via internationalization.
  #
  #   <% if children = name.children %>
  #     <%= rank_as_plural_string(children.first.rank) %>:<br/>
  #     <% for child in children %>
  #       &nbsp;&nbsp;<%= name_link(child) %><br/>
  #     <% end %>
  #   <% end %>
  def rank_as_plural_string(rank)
    eval(":rank_plural_#{rank.to_s.downcase}.l")
  end

  # Wrap some HTML in the cute red/yellow/green box used for +flash[:notice]+.
  #
  #   <%= boxify(2, flash[:notice]) %>
  #
  #   <% boxify(1) do %>
  #     Render more stuff in here.
  #   <% end %>
  #
  #   <%= boxify(0) %>
  #     Render stuff in here.
  #   <%= end_boxify %>
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
    if msg
      msg = "<div style='width:500px'>
        <table class='#{type}'><tr><td>
          #{msg}
        </td></tr></table>
      </div>"
    else
      msg = "<div style='width:500px'>
        <table class='#{type}'><tr><td>"
    end
    if block_given?
      concat(msg, block.binding)
    else
      msg
    end
  end

  # Close boxify start tag.  Only necessary if no message or block given.
  def end_boxify
    "  </td></tr></table>
    </div>"
  end
end
