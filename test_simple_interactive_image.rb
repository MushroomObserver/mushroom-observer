require "test_helper"

class SimpleInteractiveImageTest < UnitTestCase
  def test_render_interactive_image_with_image
    img = images(:connected_coprinus_comatus_image)
    puts "\n=== Image Info ==="
    puts "Image ID: #{img.id}"
    puts "Image class: #{img.class}"
    
    component = Components::InteractiveImage.new(
      user: users(:rolf),
      image: img
    )
    
    html = component.call
    puts "\n=== HTML Output ==="
    puts html
    
    # Check for the image CSS class
    assert_includes(html, "image_#{img.id}")
  end
end
