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
#  ---
#  calc_search_params::    Link params needed to fix search state.
#  ---
#  pagination_letters::    Render the set of letters for pagination.
#  pagination_numbers::    Render nearby page numbers for pagination.
#  ---
#  draw_interest_icons::   Draw the three cutesy eye icons.
#
################################################################################

module ApplicationHelper
  require_dependency 'auto_complete_helper'
  require_dependency 'javascript_helper'
  require_dependency 'map_helper'
  require_dependency 'tab_helper'
  require_dependency 'textile_helper'
  include Autocomplete
  include Javascript
  include Map
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
  def where_string(where, count=nil)
    result = sanitize(where).t
    result += " (#{count})" if count
    result = "<span class=\"Data\">#{result}</span>"
  end

  # Wrap location name in link to show_location / where_search.
  #
  #   Where: <%= location_link(obs.where, obs.location_id) %>
  def location_link(where, location_id, count=nil, click=false)
    if location_id
      loc = Location.find(location_id)
      link_string = where_string(loc.display_name, count)
      link_string += " [#{:app_click_for_map.t}]" if click
      result = link_to(link_string, :controller => 'location', :action => 'show_location', :id => location_id)
    else
      link_string = where_string(where, count)
      link_string += " [#{:app_search.t}]" if click
      result = link_to(link_string, :controller => 'location', :action => 'where_search', :where => where)
    end
    result
  end

  # Wrap name in link to show_name.
  #
  #   Parent: <%= name_link(name.parent) %>
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

  # Return a hash of parameters required to fix the search/sequence state.
  # Uses three "global" variables that must be set in the controller:
  #
  #   @search_seq   SearchState instance(?)
  #   @seq_key      SequenceState instance(?)
  #   @obs          Observation instance.
  #
  #   Consensus Name: <%= link_to(
  #     :controller => 'name',
  #     :action     => 'show_name',
  #     :id         => @obs.name_id,
  #     :params     => calc_search_params
  #   ) %>
  #
  def calc_search_params
    search_params = {}
    search_params[:search_seq] = @search_seq if @search_seq
    search_params[:seq_key] = @seq_key if @seq_key
    search_params[:obs] = @obs if @obs
    search_params
  end

  # Insert letter pagination links.  For more information see
  # ApplicationController#paginate_letters.
  #
  #   # In controller:
  #   def action
  #     @names = Name.find(...)
  #     @letters, @subset = paginate_letters(@names, len)
  #     @pages, @subset   = paginate_array(@subset, len)
  #   end
  #
  #   # In view:
  #   <div class="pagination"><%= pagination_letters(@letters) %></div>
  #   <div class="pagination"><%= pagination_numbers(@pages, @letters) %></div>
  #
  def pagination_letters(letters, args={})
    if letters
      params = (args[:params] || {}).clone
      str = %w(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z).map do |letter|
        params[letters.arg] = letter
        letters.used[letter] ? link_to(letter, params) : letter
      end.join(' ')
      return %(<div class="pagination">#{str}</div>)
    else
      return ''
    end
  end

  # Wrapper on ActionView::Helpers#pagination_links designed to work with
  # pagination_letters.  (Just needs to add a parameter to the pagination
  # links, that's all.)  (See +pagination_letters+ a>bove.)
  def pagination_numbers(pages, letters=nil, args={})
    if letters
      args[:params] ||= {}
      args[:params][letters.arg] = letters.letter
    end
    str = pagination_links(pages, args)
    if !str.to_s.empty?
      arg = args[:name] || :page
      page = params[arg].to_i
      page = 1 if page < 1
      page = pages.length if page > pages.length
      if page > 1
        url = h(reload_with_args(arg => page - 1))
        str = link_to('&laquo; ' + :app_prev.t, url) + ' | ' + str
      end
      if page < pages.length
        url = h(reload_with_args(arg => page + 1))
        str = str + ' | ' + link_to(:app_next.t + ' &raquo;', url)
      end
      return %(<div class="pagination">#{str}</div>)
    else
      return ''
    end
  end

  # Draw the cutesy eye icons in the upper right side of screen.  It does it
  # by creating a "right" tab set.  Thus this must be called in the header of
  # the view and must not actually be rendered.  Typical usage would be:
  #
  #   # At top of view:
  #   <%
  #     # Specify the page's title.
  #     @title = "Page Title"
  #
  #     # Define set of linked text tabs for top-left.
  #     new_tab_set do
  #       add_tab("Tab Label One", :link => args, ...)
  #       add_tab("Tab Label Two", :link => args, ...)
  #       ...
  #     end
  #
  #     # Draw interest icons in the top-right.
  #     draw_interest_icons(@observation, @interest) if @user
  #   %>
  #
  # This will cause the set of three icons to be rendered floating in the
  # top-right corner of the content portion of the page.
  #
  def draw_interest_icons(object, interest)
    type  = object.class.to_s.underscore.to_sym
    type2 = object.class.to_s
    if !@interest
      alt1 = :interest_watch_help.l(:object => type.l)
      alt2 = :interest_ignore_help.l(:object => type.l)
      img1 = image_tag('watch3.png',  :alt => alt1, :width => '23px', :height => '23px', :class => 'interest_small')
      img2 = image_tag('ignore3.png', :alt => alt2, :width => '23px', :height => '23px', :class => 'interest_small')
      img1 = link_to(img1, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => 1)
      img2 = link_to(img2, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => -1)
      img1 = add_context_help(img1, alt1)
      img2 = add_context_help(img2, alt2)
      add_right_tab("<div>#{img1} #{img2}</div>")
    elsif @interest.state
      alt1 = :interest_watching.l(:object => type.l)
      alt2 = :interest_default_help.l(:object => type.l)
      alt3 = :interest_ignore_help.l(:object => type.l)
      img1 = image_tag('watch2.png',    :alt => alt1, :width => '50px', :height => '50px', :class => 'interest_big')
      img2 = image_tag('halfopen3.png', :alt => alt2, :width => '23px', :height => '23px', :class => 'interest_small')
      img3 = image_tag('ignore3.png',   :alt => alt3, :width => '23px', :height => '23px', :class => 'interest_small')
      img2 = link_to(img2, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => 0)
      img3 = link_to(img3, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => -1)
      img1 = add_context_help(img1, alt1)
      img2 = add_context_help(img2, alt2)
      img3 = add_context_help(img3, alt3)
      add_right_tab("<div>#{img1}<br/>#{img2}#{img3}</div>")
    else
      alt1 = :interest_ignoring.l(:object => type.l)
      alt2 = :interest_watch_help.l(:object => type.l)
      alt3 = :interest_default_help.l(:object => type.l)
      img1 = image_tag('ignore2.png',   :alt => alt1, :width => '50px', :height => '50px', :class => 'interest_big')
      img2 = image_tag('watch3.png',    :alt => alt2, :width => '23px', :height => '23px', :class => 'interest_small')
      img3 = image_tag('halfopen3.png', :alt => alt3, :width => '23px', :height => '23px', :class => 'interest_small')
      img2 = link_to(img2, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => 1)
      img3 = link_to(img3, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => 0)
      img1 = add_context_help(img1, alt1)
      img2 = add_context_help(img2, alt2)
      img3 = add_context_help(img3, alt3)
      add_right_tab("<div>#{img1}<br/>#{img2}#{img3}</div>")
    end
  end
end
