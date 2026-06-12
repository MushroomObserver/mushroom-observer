# frozen_string_literal: true

require("test_helper")

class TabExternalSearchTest < UnitTestCase
  def test_google_maps
    tab = Tab::ExternalSearch.new(site: :Google_Maps, query: "Burbank")

    assert_equal("Google Maps", tab.title)
    assert_equal("https://maps.google.com/maps?q=Burbank", tab.path)
    assert_equal("search_link_to_Google_Maps_Burbank",
                 tab.html_options[:id])
  end

  def test_google_search
    tab = Tab::ExternalSearch.new(site: :Google_Search, query: "Foo")

    assert_equal("Google Search", tab.title)
    assert_equal("https://www.google.com/search?q=Foo", tab.path)
  end

  def test_wikipedia
    tab = Tab::ExternalSearch.new(site: :Wikipedia, query: "Bar")

    assert_equal("Wikipedia", tab.title)
    assert_equal("https://en.wikipedia.org/w/index.php?search=Bar",
                 tab.path)
  end

  def test_sites_class_method
    assert_equal([:Google_Maps, :Google_Search, :Wikipedia],
                 Tab::ExternalSearch.sites)
  end

  def test_unknown_site_raises
    assert_raises(KeyError) do
      Tab::ExternalSearch.new(site: :Unknown, query: "X").path
    end
  end
end
