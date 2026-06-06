# frozen_string_literal: true

require("test_helper")

class FormLocationsHelperTest < ActionView::TestCase
  include FormLocationsHelper
  include FormsHelper
  include PanelHelper
  include LinkHelper

  def setup
    @location = locations(:obs_default_location)
    @form = ActionView::Helpers::FormBuilder.new(
      :location, @location, self, {}
    )
  end

  # -- pure Ruby helpers ------------------------------------------------

  def test_compass_groups
    assert_equal([:north, [:west, :east], :south], compass_groups,
                 "Expected compass groups to list all cardinal directions")
  end

  def test_compass_north_south
    assert_equal([:north, :south], compass_north_south,
                 "Expected north-south set")
  end

  def test_elevation_directions
    assert_equal([:high, :low], elevation_directions,
                 "Expected elevation directions")
  end

  def test_compass_row_classes
    assert_equal("row vcenter", compass_row_classes(:north),
                 "Expected no margin-top for north row")
    assert_equal("row vcenter mt-3", compass_row_classes(:south),
                 "Expected margin-top for non-north rows")
  end

  def test_compass_col_classes
    assert_equal("col-xs-4 text-center",
                 compass_col_classes(:west),
                 "Expected offset-free class for east/west")
    assert_equal("col-xs-4 col-xs-offset-4 text-center",
                 compass_col_classes(:north),
                 "Expected offset class for north/south")
  end

  # -- HTML helpers (no form required) ----------------------------------

  def test_compass_help
    doc = Nokogiri::HTML(compass_help)
    assert(doc.at_css("div"), "Expected compass_help to render a div")
  end

  def test_elevation_request_button
    doc = Nokogiri::HTML(elevation_request_button)
    assert(doc.at_css("button[data-action*='map#getElevations']"),
           "Expected elevation request button with map action")
  end

  # -- form helpers -----------------------------------------------------

  def test_form_location_input_find_on_map
    html = form_location_input_find_on_map(form: @form, field: :where)
    doc = Nokogiri::HTML(html)

    assert(doc.at_css("[data-map-target='placeInput']"),
           "Expected place input Stimulus target")
    assert(doc.at_css("[data-map-target='showBoxBtn']"),
           "Expected show box button Stimulus target")
  end

  def test_form_compass_input_group
    html = form_compass_input_group(form: @form, obj: @location)
    doc = Nokogiri::HTML(html)

    [:north, :south, :east, :west].each do |dir|
      assert(doc.at_css("[data-map-target='#{dir}Input']"),
             "Expected #{dir} compass input Stimulus target")
    end
  end

  def test_form_elevation_input_group
    html = form_elevation_input_group(form: @form, obj: @location)
    doc = Nokogiri::HTML(html)

    [:high, :low].each do |dir|
      assert(doc.at_css("[data-map-target='#{dir}Input']"),
             "Expected #{dir} elevation input Stimulus target")
    end
    assert(doc.at_css("[data-map-target='getElevation']"),
           "Expected get elevation button Stimulus target")
  end
end
