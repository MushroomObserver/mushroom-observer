# frozen_string_literal: true

require("test_helper")

module Tab::Location
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @location = locations(:albion)
    end

    def test_new
      tab = Tab::Location::New.new

      assert_equal(:show_location_create.t, tab.title)
      assert_equal(routes.new_location_path, tab.path)
      assert_equal(:add, tab.html_options[:icon])
      assert_equal(Location, tab.model)
    end

    def test_map
      bare = Tab::Location::Map.new
      with_q = Tab::Location::Map.new(q_param: "X")

      assert_equal(:list_place_names_map.t, bare.title)
      assert_equal(routes.map_locations_path, bare.path)
      assert_equal(routes.map_locations_path(q: "X"), with_q.path)
    end

    def test_countries
      tab = Tab::Location::Countries.new

      assert_equal(:list_countries.t, tab.title)
      assert_equal(routes.location_countries_path, tab.path)
    end

    def test_edit
      tab = Tab::Location::Edit.new(location: @location)

      assert_equal(:show_location_edit.t, tab.title)
      assert_equal(routes.edit_location_path(@location.id), tab.path)
      assert_equal(:edit, tab.html_options[:icon])
      assert_equal(@location, tab.model)
    end

    def test_reverse_order
      tab = Tab::Location::ReverseOrder.new(location: @location)

      assert_equal(:show_location_reverse.t, tab.title)
      assert_equal(routes.reverse_name_order_location_path(@location.id),
                   tab.path)
      assert_equal(:back, tab.html_options[:icon])
    end

    def test_index
      tab = Tab::Location::Index.new

      assert_equal(:all_objects.t(type: :location), tab.title)
      assert_equal(routes.locations_path, tab.path)
      assert_equal(Location, tab.model)
    end

    def test_versions
      tab = Tab::Location::Versions.new(location: @location)

      assert_equal(:show_location.t(location: @location.display_name),
                   tab.title)
      assert_equal(routes.location_path(@location.id), tab.path)
      assert_equal(:show_object.t(TYPE: Location), tab.alt_title)
    end

    def test_observations_at_title_format
      tab = Tab::Location::ObservationsAt.new(location: @location)

      assert_match(/\A.* \(\d+\)\z/, tab.title)
      assert_equal(:show_location_observations.t, tab.alt_title)
      assert_equal(:observations, tab.html_options[:icon])
    end
  end
end
