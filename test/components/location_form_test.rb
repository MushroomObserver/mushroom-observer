# frozen_string_literal: true

require "test_helper"

class LocationFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @location = Location.new
  end

  def test_renders_new_location_form_with_all_fields
    html = render_form

    # Form structure
    assert_html(html, "form#location_form[action*='/locations'][method='post']")
    assert_html(
      html,
      "form#location_form[data-controller='map'][data-map-open='true']"
    )

    # All input fields
    assert_html(html, "input[name='location[display_name]']")
    %w[north south east west].each do |dir|
      assert_html(html, "input[name='location[#{dir}]']")
    end
    %w[high low].each do |dir|
      assert_html(html, "input[name='location[#{dir}]']")
    end
    # Compass inputs have º suffix, elevation inputs have m suffix
    assert_html(html, ".input-group-addon", count: 6)
    assert_html(html, "textarea[name='location[notes]']")
    assert_html(html, "input[type='checkbox'][name='location[hidden]']")

    # Map with editable settings
    assert_html(
      html, "#map_div[data-editable='true'][data-map-type='location']"
    )

    # Find on map button
    assert_html(
      html,
      "button[data-map-target='showBoxBtn'][data-action='map#showBox']"
    )

    # Display name input group
    assert_html(html, ".input-group")
    assert_html(html, ".input-group-btn")

    # Submit button for new record
    assert_html(html, "input[type='submit'][value='#{:CREATE.l}']")

    # No turbo for local form
    assert_no_html(html, "form[data-turbo]")

    # No locked checkbox for regular users
    assert_no_html(html, "input[name='location[locked]']")

    # No dubious warning when not provided
    assert_no_html(html, "#dubious_location_messages")
  end

  def test_renders_existing_location_form
    location = locations(:burbank)
    html = render(Components::LocationForm.new(
                    location,
                    display_name: location.display_name,
                    original_name: location.display_name,
                    local: true
                  ))

    assert_html(html, "form[action*='/locations/#{location.id}']")
    assert_html(html, "input[type='submit'][value='#{:UPDATE.l}']")
  end

  def test_renders_locked_checkbox_in_admin_mode
    User.current = users(:zero_user)
    stub_admin_mode!
    html = render_form

    assert_html(html, "input[type='checkbox'][name='location[locked]']")
  end

  def test_renders_dubious_location_warning_container_when_provided
    html = render(Components::LocationForm.new(
                    @location,
                    display_name: "test",
                    original_name: "test",
                    dubious_where_reasons: ["Reason 1", "Reason 2"],
                    local: true
                  ))

    assert_html(html, "#dubious_location_messages.alert-warning")
    assert_html(html, "#dubious_location_messages", text: "Reason 1")
    assert_html(html, "#dubious_location_messages", text: "Reason 2")
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

    assert_html(html, "body", text: :show_location_locked.l)
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
