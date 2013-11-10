module LocationHelper
  
  def country_link(country, count=nil)
    result = link_to(country + (count ? ": #{count}" : ""), :action => "list_by_country", :country => country) + "<br/>\n"
  end

end
