# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations
  class Form::LocationHelpTest < ComponentTestCase
    # `User.current_location_format` is thread-local — restore in `ensure`
    # to keep tests order-independent.
    def test_renders_two_paragraphs_with_postal_examples_by_default
      previous_format = User.current_location_format
      User.current_location_format = "postal"
      html = render(Form::LocationHelp.new)

      # Postal: postal-format example city appears as written.
      assert_includes(html, Form::LocationHelp::POSTAL_LOC1)
      assert_includes(html, Form::LocationHelp::POSTAL_LOC2)
      # Map-help paragraph also rendered (second `<div>`).
      assert_includes(html, :form_observations_locate_on_map_help.t)
    ensure
      User.current_location_format = previous_format
    end

    def test_scientific_format_flips_example_locations
      previous_format = User.current_location_format
      User.current_location_format = "scientific"
      html = render(Form::LocationHelp.new)

      # Scientific: reverse-name flip on the example cities.
      assert_includes(html,
                      Location.reverse_name(Form::LocationHelp::POSTAL_LOC1))
      assert_includes(html,
                      Location.reverse_name(Form::LocationHelp::POSTAL_LOC2))
    ensure
      User.current_location_format = previous_format
    end
  end
end
