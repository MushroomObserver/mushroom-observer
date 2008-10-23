require_dependency 'javascript'
require_dependency 'auto_complete'
require_dependency 'tab_helper'
require_dependency 'textile_helper'
require_dependency 'string_extensions'
require_dependency 'symbol_extensions'

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  # Replace spaces with '&nbsp;'.
  def lnbsp(key)
    key.l.gsub(' ', '&nbsp;')
  end

  # Returns '<span>where (count)</span>'.
  def where_string(where, count)
    result = sanitize(where).t
    result += " (#{count})" if count
    result = "<span class=\"Data\">#{result}</span>"
  end

  # Returns link to the given location.
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

  # Returns link to the given user.
  def user_link(user, name=nil)
    begin
      name = h(user.unique_text_name) if name.nil?
      link_to(name, :controller => 'observer', :action => 'show_user', :id => user)
    rescue
    end
  end

  # Returns link to the given project.
  def project_link(project, name=nil)
    begin
      name = sanitize(project.title).t if name.nil?
      link_to(name, :controller => 'project', :action => 'show_project', :id => project.id)
    rescue
    end
  end

  # Convert :Genus to "Genus" via internationalization.
  def rank_as_string(rank)
    eval(":rank_#{rank.to_s.downcase}.l")
  end

  # Convert :Genus to "Genera" via internationalization.
  def rank_as_plural_string(rank)
    eval(":rank_plural_#{rank.to_s.downcase}.l")
  end

  # Wrap some body text in the cute red/yellow/green box used for flash[:notice].
  # Note: the &block thing doesn't work, despite apparently being indentical to
  # the way form_tag does it.  Beats me.
  def boxify(lvl, msg=nil, &block)
    type = "Notices"  if lvl == 0 || !lvl
    type = "Warnings" if lvl == 1
    type = "Errors"   if lvl == 2
    msg = capture(&block) if block_given?
    if msg
      "<div style='width:500px'>
        <table class='#{type}'><tr><td>
          #{msg}
        </td></tr></table>
      </div>"
    else
      "<div style='width:500px'>
        <table class='#{type}'><tr><td>"
    end
  end

  def end_boxify
    "  </td></tr></table>
    </div>"
  end

  # Return a hash of parameters required to fix the search/sequence state.
  def calc_search_params
    search_params = {}
    search_params[:search_seq] = @search_seq if @search_seq
    search_params[:seq_key] = @seq_key if @seq_key
    search_params[:obs] = @obs if @obs
    search_params
  end

  # Insert letter pagination links.  See ApplicationController#paginate_letters.
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
  # links, that's all.)
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
        url = reload_with_args(arg => page - 1)
        str = link_to('&laquo; ' + :app_prev.t, url) + ' | ' + str
      end
      if page < pages.length
        url = reload_with_args(arg => page + 1)
        str = str + ' | ' + link_to(:app_next.t + ' &raquo;', url)
      end
      return %(<div class="pagination">#{str}</div>)
    else
      return ''
    end
  end

  # Get sorted list of locale codes we have translations for.
  def all_locales
    Dir.glob(RAILS_ROOT + '/lang/ui/*.yml').sort.map do |file|
      file.sub(/.*?(\w+-\w+).yml/, '\\1')
    end
  end
end
