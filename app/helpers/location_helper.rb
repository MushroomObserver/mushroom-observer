module LocationHelper
  def country_link(country, count = nil)
    str = country + (count ? ": #{count}" : "")
    result = link_to(str, action: :list_by_country, country: country)
  end
end
