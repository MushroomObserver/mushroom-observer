# frozen_string_literal: true

require("test_helper")

module Tab::Location
  class CollectionsTest < UnitTestCase
    def setup
      @location = locations(:albion)
    end

    def test_index_actions_no_query
      tabs = Tab::Location::IndexActions.new.to_a

      assert_includes(tabs.map(&:class),
                      Tab::Location::New)
      assert_includes(tabs.map(&:class),
                      Tab::Location::Map)
      assert_includes(tabs.map(&:class),
                      Tab::Location::Countries)
    end

    def test_version_actions
      tabs = Tab::Location::VersionActions.new(
        location: @location
      ).to_a

      assert_equal([Tab::Location::Versions], tabs.map(&:class))
    end

    def test_countries_actions
      tabs = Tab::Location::CountriesActions.new.to_a

      assert_equal([Tab::Location::Index], tabs.map(&:class))
    end

    def test_form_new_without_name
      bare = Location.new
      tabs = Tab::Location::FormNew.new(location: bare).to_a

      assert_equal([Tab::Location::Index], tabs.map(&:class))
    end

    def test_form_new_with_name_adds_external_search
      tabs = Tab::Location::FormNew.new(location: @location).to_a

      assert_instance_of(Tab::Location::Index, tabs.first)
      assert(tabs.drop(1).any?(Tab::ExternalSearch),
             "expected external search tabs after Index")
    end

    def test_form_edit
      tabs = Tab::Location::FormEdit.new(location: @location).to_a

      assert_instance_of(Tab::Location::Index, tabs[0])
      assert_instance_of(Tab::Object::Return, tabs[1])
      assert(tabs.drop(2).any?(Tab::ExternalSearch),
             "expected external search tabs after Index + Return")
    end

    def test_external_search_three_sites
      tabs = Tab::Location::ExternalSearch.new(
        name: @location.name
      ).to_a

      assert_equal(3, tabs.length)
      tabs.each { |t| assert_kind_of(Tab::ExternalSearch, t) }
    end

    def test_external_search_normalizes_name
      tabs = Tab::Location::ExternalSearch.new(
        name: "Burbank Co., California, USA"
      ).to_a

      # Test normalization: " Co." → " County", ", USA" stripped,
      # spaces → "+", commas → "%2C".
      query = tabs.first.path
      assert_includes(query, "Burbank+County")
      assert_not_includes(query, "+USA")
    end
  end
end
