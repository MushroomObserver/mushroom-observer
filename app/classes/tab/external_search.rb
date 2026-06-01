# frozen_string_literal: true

# External search link — Google Maps / Google Search / Wikipedia
# lookups for a given query string. Replaces
# `Tabs::GeneralHelper#search_tab_for` and `#external_search_urls`.
class Tab::ExternalSearch < Tab::Base
  URLS = {
    Google_Maps: "https://maps.google.com/maps?q=",
    Google_Search: "https://www.google.com/search?q=",
    Wikipedia: "https://en.wikipedia.org/w/index.php?search="
  }.freeze

  def self.sites
    URLS.keys
  end

  def initialize(site:, query:)
    super()
    @site = site
    @query = query
  end

  def title
    @site.to_s.titlecase
  end

  def path
    "#{URLS.fetch(@site)}#{@query}"
  end

  def html_options
    { id: "search_link_to_#{@site}_#{@query}" }
  end
end
