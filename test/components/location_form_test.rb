# frozen_string_literal: true

require "test_helper"

class LocationFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @user = users(:rolf)
    @location = Location.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_display_name_field
    html = render_form

    assert_html(html, "input[name='location[display_name]']")
  end

  def test_renders_form_with_compass_inputs
    html = render_form

    %w[north south east west].each do |dir|
      assert_html(html, "input[name='location[#{dir}]']")
    end
  end

  def test_renders_form_with_elevation_inputs
    html = render_form

    %w[high low].each do |dir|
      assert_html(html, "input[name='location[#{dir}]']")
    end
  end

  def test_renders_form_with_notes_field
    html = render_form

    assert_html(html, "textarea[name='location[notes]']")
  end

  def test_renders_form_with_hidden_checkbox_for_new_location
    html = render_form

    assert_html(html, "input[type='checkbox'][name='location[hidden]']")
  end

  def test_renders_form_with_map_div
    html = render_form

    assert_html(html, "#map_div")
  end

  def test_renders_create_button_for_new_record
    html = render_form

    assert_html(html, "input[type='submit'][value='#{:CREATE.l}']")
  end

  def test_renders_update_button_for_existing_record
    location = locations(:burbank)
    html = render(Components::LocationForm.new(
                    location,
                    display_name: location.display_name,
                    original_name: location.display_name,
                    local: true
                  ))

    assert_html(html, "input[type='submit'][value='#{:UPDATE.l}']")
  end

  def test_renders_form_with_correct_action_for_create
    html = render_form

    assert_html(html, "form[action*='/locations']")
    assert_html(html, "form[method='post']")
  end

  def test_renders_form_with_correct_action_for_update
    location = locations(:burbank)
    html = render(Components::LocationForm.new(
                    location,
                    display_name: location.display_name,
                    original_name: location.display_name,
                    local: true
                  ))

    assert_html(html, "form[action*='/locations/#{location.id}']")
  end

  def test_renders_form_with_map_controller
    html = render_form
    doc = Nokogiri::HTML(html)
    form = doc.at_css("form#location_form")

    assert_equal("map", form["data-controller"])
  end

  def test_renders_form_with_map_open_true
    html = render_form
    doc = Nokogiri::HTML(html)
    form = doc.at_css("form#location_form")

    assert_equal("true", form["data-map-open"])
  end

  def test_renders_find_on_map_button
    html = render_form

    assert_html(html, "button[data-map-target='showBoxBtn']")
    assert_html(html, "button[data-action='map#showBox']")
    assert_includes(html, :form_locations_find_on_map.l)
  end

  def test_renders_input_group_for_display_name
    html = render_form

    assert_html(html, ".input-group")
    assert_html(html, ".input-group-btn")
  end

  def test_renders_map_with_editable_true
    html = render_form
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("true", map_div["data-editable"])
  end

  def test_renders_map_with_location_type
    html = render_form
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("location", map_div["data-map-type"])
  end

  def test_renders_locked_checkbox_in_admin_mode
    User.current = users(:zero_user)
    html = render_form

    assert_html(html, "input[type='checkbox'][name='location[locked]']")
  end

  def test_omits_locked_checkbox_for_regular_users
    User.current = users(:rolf)
    html = render_form
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("input[name='location[locked]']"))
  end

  def test_renders_dubious_location_warning_when_provided
    html = render(Components::LocationForm.new(
                    @location,
                    display_name: "test",
                    original_name: "test",
                    dubious_where_reasons: ["Reason 1", "Reason 2"],
                    local: true
                  ))

    assert_includes(html, "Reason 1")
    assert_includes(html, "Reason 2")
    assert_html(html, "#dubious_location_messages")
  end

  def test_omits_dubious_warning_when_not_provided
    html = render_form
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("#dubious_location_messages"))
  end

  def test_renders_locked_display_for_locked_location
    location = locations(:burbank)
    location.update!(locked: true)
    User.current = users(:rolf) # non-admin

    html = render(Components::LocationForm.new(
                    location,
                    display_name: location.display_name,
                    original_name: location.display_name,
                    local: true
                  ))

    assert_includes(html, :show_location_locked.l)
  end

  def test_enables_turbo_for_modal_rendering
    html = render(Components::LocationForm.new(
                    @location,
                    display_name: "test",
                    original_name: "test",
                    local: false
                  ))

    assert_html(html, "form[data-turbo='true']")
  end

  def test_disables_turbo_for_local_form
    html = render_form
    doc = Nokogiri::HTML(html)
    form = doc.at_css("form")

    assert_nil(form["data-turbo"])
  end

  private

  def render_form
    render(Components::LocationForm.new(
             @location,
             display_name: "test location",
             original_name: "test location",
             local: true
           ))
  end
end
