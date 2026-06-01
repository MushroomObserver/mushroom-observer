# frozen_string_literal: true

# Collection of external-site search links (Google_Maps /
# Google_Search / Wikipedia) for a location name, with the name
# pre-massaged for URL use (county suffix shortened, "USA" trimmed,
# spaces → "+", commas → "%2C"). Replaces
# `Tabs::LocationsHelper#location_search_tabs`.
class Tab::Location::ExternalSearch < Tab::Collection
  def initialize(name:)
    super()
    @name = name
  end

  private

  def tabs
    Tab::ExternalSearch.sites.map do |site|
      Tab::ExternalSearch.new(site: site, query: search_string)
    end
  end

  def search_string
    @search_string ||= @name.gsub(" Co.", " County").gsub(", USA", "").
                       tr(" ", "+").gsub(",", "%2C")
  end
end
