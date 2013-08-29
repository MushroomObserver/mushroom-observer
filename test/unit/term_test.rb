require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class TermTest < UnitTestCase
  def ignore_test_term_load
    term = terms(:conic_term)
    assert(term)
  end
  
  def ignore_test_text_name
    term = terms(:conic_term)
    assert_equal(term.text_name, term.name)
  end
  
  def ignore_test_format_name
    term = terms(:conic_term)
    assert_equal(term.format_name, term.name)
  end
  
  def test_add_image_nil
    term = terms(:conic_term)
    image = term.thumb_image
    images = term.images
    assert_equal(image.id, images[0].id)
    term.add_image(nil)
    assert_equal(image, term.thumb_image)
    assert_equal(images, term.images)
  end
  
  def ignore_test_add_image_additional
    term = terms(:conic_term)
    image = term.thumb_image
    images_length = term.images.length
    additional_image = images(:convex_image)
    term.add_image(additional_image)
    term.reload
    assert_equal(image, term.thumb_image)
    assert_equal(1, term.images.length - images_length)
    assert(term.images.member?(additional_image))
  end
  
  def ignore_test_add_image_first
    term = terms(:convex_term)
    assert(term.thumb_image.nil?)
    assert_equal(0, term.images.length)
    images = term.images
    first_image = images(:convex_image)
    term.add_image(first_image)
    assert_equal(first_image, term.thumb_image)
    assert_equal(1, term.images.length)
    assert(term.images.member?(first_image))
  end

end
