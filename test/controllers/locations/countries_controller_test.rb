# frozen_string_literal: true

require("test_helper")

module Locations
  class CountriesControllerTest < FunctionalTestCase
    # include ObjectLinkHelper

    def test_list_countries
      cc = CountryCounter.new
      links_to_countries_with_obss = cc.known_by_count.length
      links_to_other_localities_with_obss = cc.unknown_by_count.length

      login
      get(:index)

      assert_displayed_title(:list_countries_title.l)
      assert_select(
        "a:match('href', ?)", %r{^/locations\?country=\S+},
        { count: links_to_countries_with_obss +
                 links_to_other_localities_with_obss },
        "Wrong number of links to countries and other localities"
      )
    end
  end
end
