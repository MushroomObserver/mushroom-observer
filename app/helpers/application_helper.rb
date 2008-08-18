require_dependency 'auto_complete'

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def lnbsp(key)
    key.l.gsub(' ', '&nbsp;')
  end

  def where_string(where, count)
    result = h(where)
    result += " (#{count})" if count
    result = "<span class=\"Data\">#{result}</span>"
  end

  def location_link(where, location_id, count=nil, click=false)
    if location_id
      loc = Location.find(location_id)
      link_string = where_string(loc.display_name, count)
      link_string += " [Click for map]" if click
      result = link_to(link_string, :controller => 'location', :action => 'show_location', :id => location_id)
    else
      link_string = where_string(where, count)
      link_string += " [Search]" if click
      result = link_to(link_string, :controller => 'location', :action => 'where_search', :where => where)
    end
    result
  end

  def user_link(user, name=nil)
    begin
      name = h(user.unique_text_name) if name.nil?
      link_to(name, :controller => 'observer', :action => 'show_user', :id => user)
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
  
  def calc_search_params
    search_params = {}
    search_params[:search_seq] = @search_seq if @search_seq
    search_params[:seq_key] = @seq_key if @seq_key
    search_params[:obs] = @obs if @obs
    search_params
  end

  # This is a temporary place-holder used to display the tabs in the upper
  # left of the page body.  Some day we'd like to do something to make these
  # more visible.
  def show_tabs(tabs)
    tabs.map do |args|
      str, url = *args
      if url.is_a?(String) && (url[0..6] == 'http://')
        "<a href=\"#{url}\" target=\"_new\">#{str}</a>"
      else
        link_to(*args)
      end
    end.join(' | ')
  end

  # Insert letter pagination links.  See ApplicationController#paginate_letters.
  def pagination_letters(letters, args={})
    if letters
      params = (args[:params] || {}).clone
      %w(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z).map do |letter|
        params[letters.arg] = letter
        letters.used[letter] ? link_to(letter, params) : letter
      end.join(' ')
    else
      ''
    end
  end

  # Wrapper on ActionView::Helpers#pagination_links designed to work with
  # pagination_letters.  (Just needs to add a parameter to the pagination
  # links, that's all.)
  def pagination_numbers(pages, letters, args={})
    if letters
      args[:params] ||= {}
      args[:params][letters.arg] = letters.letter
    end
    pagination_links(pages, args)
  end
end
