# frozen_string_literal: true

require("test_helper")

# Output-parity tests: PORO `.to_a` == legacy `InternalLink.tab`
# (byte-for-byte copies of `Tabs::LocationsHelper` method bodies).
module Tab::Location
  class ParityTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @location = locations(:albion)
    end

    def test_new
      expected = ::InternalLink::Model.new(
        :show_location_create.t, Location,
        routes.new_location_path,
        html_options: { icon: :add }
      ).tab

      assert_equal(expected, Tab::Location::New.new.to_a)
    end

    def test_countries
      expected = ::InternalLink.new(
        :list_countries.t, routes.location_countries_path
      ).tab

      assert_equal(expected, Tab::Location::Countries.new.to_a)
    end

    def test_edit
      expected = ::InternalLink::Model.new(
        :show_location_edit.t, @location,
        routes.edit_location_path(@location.id),
        html_options: { icon: :edit }
      ).tab

      actual = Tab::Location::Edit.new(location: @location).to_a
      assert_equal(expected, actual)
    end

    def test_reverse_order
      expected = ::InternalLink::Model.new(
        :show_location_reverse.t, @location,
        routes.reverse_name_order_location_path(@location.id),
        html_options: { icon: :back }
      ).tab

      actual = Tab::Location::ReverseOrder.new(location: @location).to_a
      assert_equal(expected, actual)
    end

    def test_versions
      expected = ::InternalLink::Model.new(
        :show_location.t(location: @location.display_name), @location,
        routes.location_path(@location.id),
        alt_title: :show_object.t(TYPE: Location)
      ).tab

      actual = Tab::Location::Versions.new(location: @location).to_a
      assert_equal(expected, actual)
    end

    def test_index
      expected = ::InternalLink::Model.new(
        :all_objects.t(type: :location), Location, routes.locations_path
      ).tab

      assert_equal(expected, Tab::Location::Index.new.to_a)
    end
  end
end
