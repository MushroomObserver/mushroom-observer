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
  
  def where_search(where, count)
    result = link_to(where_string(where, count), :controller => 'observer', :action => 'where_search', :where => where)
  end
  
  def location_link(where, location_id, count=nil)
    if location_id
      loc = Location.find(location_id)
      result = link_to(where_string(loc.display_name, count), :controller => 'location', :action => 'show_location', :id => location_id)
    else
      result = "#{where_search(where, count)}"
    end
    result
  end
end
