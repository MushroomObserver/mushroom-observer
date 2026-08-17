# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Locations
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @location = Location.new
    end

    def test_renders_new_location_form_with_all_fields
      html = render_form

      # Form structure
      assert_html(
        html, "form#location_form[action*='/locations'][method='post']"
      )
      assert_html(
        html,
        "form#location_form[data-controller~='map'][data-map-open='true']"
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

      # Place input — the Stimulus target geocode_controller.js reads
      assert_html(
        html,
        "input[name='location[display_name]'][data-map-target='placeInput']"
      )

      # Flash slot for Google Maps API failures (issue #4535).
      assert_html(html, "#gmaps_flash")

      # Display name input group
      assert_html(html, ".input-group")
      assert_html(html, ".input-group-btn")

      # Submit button for new record
      assert_html(html, "button[type='submit']", text: :create.ti)

      # No turbo for local form
      assert_html(html, "form[data-turbo='false']")

      # No locked checkbox for regular users
      assert_no_html(html, "input[name='location[locked]']")

      # No dubious warning when not provided
      assert_no_html(html, "#dubious_location_messages")
    end

    def test_renders_existing_location_form
      location = locations(:burbank)
      html = render_form(location,
                         display_name: location.display_name,
                         original_name: location.display_name)

      assert_html(html, "form[action*='/locations/#{location.id}']")
      assert_html(html, "button[type='submit']", text: :update.ti)
    end

    def test_renders_locked_checkbox_in_admin_mode
      stub_admin_mode!
      html = render_form

      assert_html(html, "input[type='checkbox'][name='location[locked]']")
    end

    def test_renders_dubious_location_warning_container_when_provided
      reasons = [[:location_dubious_empty, {}], [:location_dubious_commas, {}]]
      html = render_form(@location,
                         display_name: "test", original_name: "test",
                         dubious_where_reasons: reasons)

      assert_html(html, "#dubious_location_messages.alert-warning")
      reasons.each do |tag, args|
        assert_html(html, "#dubious_location_messages",
                    text: tag.t(**args).as_displayed)
      end
    end

    def test_renders_locked_display_for_locked_location
      location = locations(:burbank)
      location.update!(locked: true)

      html = render_form(location,
                         display_name: location.display_name,
                         original_name: location.display_name)

      # Locked-display style: the explanatory text lives in a
      # `.help-block` div next to the read-only fields.
      assert_html(html, ".help-block", text: :show_location_locked.l)
    end

    def test_enables_turbo_for_modal_rendering
      html = render_form(@location, display_name: "test",
                                    original_name: "test", turbo: true)

      assert_html(html, "form[data-turbo='true']")
    end

    private

    def render_form(location = @location, turbo: false, **)
      render(Form.new(
               location,
               display_name: "test location",
               original_name: "test location",
               turbo: turbo,
               **
             ))
    end
  end
end
