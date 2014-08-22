require 'test_helper'

class TermTest < UnitTestCase
  def test_term_load
    term = terms(:conic_term)
    assert(term)
  end
  
  def test_text_name
    term = terms(:conic_term)
    assert_equal(term.text_name, term.name)
  end
  
  def test_format_name
    term = terms(:conic_term)
    assert_equal(term.format_name, term.name)
  end
  
  def test_add_image_nil
    term = terms(:conic_term)
    image = term.thumb_image
    images = term.images
    assert(image)
    assert_equal([], images)
    term.add_image(nil)
    assert_equal(image, term.thumb_image)
    assert_equal(images, term.images)
  end
  
  def test_add_image_additional
    term = terms(:conic_term)
    image = term.thumb_image
    assert(image)
    images_length = term.images.length
    additional_image = images(:convex_image)
    term.add_image(additional_image)
    term.reload
    assert_equal(image, term.thumb_image)
    assert_equal(1, term.images.length - images_length)
    assert(term.images.member?(additional_image))
  end
  
  def test_add_image_first
    term = terms(:convex_term)
    assert_nil(term.thumb_image)
    assert_equal(0, term.images.length)
    images = term.images # Seems like this conflicts with the next line
    first_image = images(:convex_image)
    term.add_image(first_image)
    assert_equal(first_image, term.thumb_image)
    assert_equal(0, term.images.length)
  end
  
  def test_add_image_second
    term = terms(:conic_term)
    thumb = term.thumb_image
    assert(thumb)
    assert_equal(0, term.images.length)
    images = term.images
    second_image = images(:convex_image)
    term.add_image(second_image)
    assert_equal(thumb, term.thumb_image)
    assert_equal(1, term.images.length)
    assert(term.images.member?(second_image))
  end

  def test_rss_log
    assert(Term.has_rss_log?)
    term = terms(:convex_term)
    assert(term.has_rss_log?)
  end
  
  def test_remove_image_thumb
    term = terms(:plane_term)
    thumb = term.thumb_image
    assert(thumb)
    images_length = term.images.length
    next_thumb = term.images[0]
    assert(next_thumb)
    term.remove_image(thumb)
    term.reload
    assert_not_equal(thumb, term.thumb_image)
    assert_equal(next_thumb, term.thumb_image)
    assert_equal(images_length - 1, term.images.length)
  end
  
  def test_remove_image_non_thumb
    term = terms(:plane_term)
    thumb = term.thumb_image
    assert(thumb)
    images_length = term.images.length
    first_non_thumb = term.images[0]
    assert(first_non_thumb)
    term.remove_image(first_non_thumb)
    term.reload
    assert_equal(thumb, term.thumb_image)
    assert_equal(images_length - 1, term.images.length)
  end
  
  def test_remove_image_nil
    term = terms(:plane_term)
    thumb = term.thumb_image
    assert(thumb)
    images_length = term.images.length
    term.remove_image(nil)
    term.reload
    assert_equal(thumb, term.thumb_image)
    assert_equal(images_length, term.images.length)
  end
  
  def test_remove_image_other
    term = terms(:plane_term)
    thumb = term.thumb_image
    assert(thumb)
    images_length = term.images.length
    term.remove_image(images(:conic_image))
    term.reload
    assert_equal(thumb, term.thumb_image)
    assert_equal(images_length, term.images.length)
  end
  
    # Remove an image from images
    # Remove nil
    # Remove an image that is not associated with this term
end
