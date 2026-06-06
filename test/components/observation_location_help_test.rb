# frozen_string_literal: true

require("test_helper")

class ObservationLocationHelpTest < ComponentTestCase
  def test_renders_two_paragraphs_with_postal_examples_by_default
    User.current_location_format = "postal"
    html = render(Components::ObservationLocationHelp.new)

    # Postal: postal-format example city appears as written.
    assert_includes(html, Components::ObservationLocationHelp::POSTAL_LOC1)
    assert_includes(html, Components::ObservationLocationHelp::POSTAL_LOC2)
    # Map-help paragraph also rendered (second `<div>`).
    assert_includes(html, :form_observations_locate_on_map_help.t)
  end

  def test_scientific_format_flips_example_locations
    User.current_location_format = "scientific"
    html = render(Components::ObservationLocationHelp.new)

    # Scientific: reverse-name flip on the example cities.
    assert_includes(
      html,
      Location.reverse_name(
        Components::ObservationLocationHelp::POSTAL_LOC1
      )
    )
    assert_includes(
      html,
      Location.reverse_name(
        Components::ObservationLocationHelp::POSTAL_LOC2
      )
    )
  ensure
    User.current_location_format = "postal"
  end
end
