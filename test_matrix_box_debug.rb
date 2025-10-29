# frozen_string_literal: true

require "test_helper"

class MatrixBoxDebugTest < UnitTestCase
  # rubocop:disable Metrics/AbcSize
  def test_matrix_box_observation_with_thumb
    obs = observations(:coprinus_comatus_obs)
    puts("\n\n=== Observation Info ===")
    puts("Observation ID: #{obs.id}")
    puts("Thumb Image ID: #{obs.thumb_image_id}")
    puts("Thumb Image: #{obs.thumb_image.inspect}")
    puts("Thumb Image Class: #{obs.thumb_image.class}")

    # Render the MatrixBox
    component = Components::MatrixBox.new(user: users(:rolf), object: obs)
    html = component.call

    puts("\n\n=== Rendered HTML ===")
    puts(html)

    # Check if the image class is present
    expected_class = "image_#{obs.thumb_image_id}"
    assert_includes(html, expected_class,
                    "Should include CSS class #{expected_class}")
  end
  # rubocop:enable Metrics/AbcSize
end
