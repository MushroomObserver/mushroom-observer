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
      result = "#{where_search(where, count)} #{link_to(:location_define.l, :controller => 'location', :action => 'create_location', :id => location_id, :where => where)}"
    end
    result
  end

  # Ultimately running large queries like this and storing the info in the session
  # may become unwieldy.  Storing the query and selecting chunks will scale better.
  def self.query_ids(query)
    result = []
    data = Observation.connection.select_all(query)
    for d in data
      id = d['id']
      if id
        result.push(id.to_i)
      end
    end
    result
  end

  def self.calc_layout_params(user=nil)
    result = {}
    result["rows"] = 5
    result["columns"] = 3
    result["alternate_rows"] = true
    result["alternate_columns"] = true
    result["vertical_layout"] = true
    if user
      result["rows"] = user.rows if user.rows
      result["columns"] = user.columns if user.columns
      result["alternate_rows"] = user.alternate_rows
      result["alternate_columns"] = user.alternate_columns
      result["vertical_layout"] = user.vertical_layout
    end
    result["count"] = result["rows"] * result["columns"]
    result
  end
end
