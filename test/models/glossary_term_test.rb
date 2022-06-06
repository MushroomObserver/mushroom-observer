# frozen_string_literal: true

require("test_helper")

class GlossaryTermTest < UnitTestCase
  def test_glossary_term_load
    glossary_term = glossary_terms(:conic_glossary_term)
    assert(glossary_term)
  end

  def test_text_name
    glossary_term = glossary_terms(:conic_glossary_term)
    assert_equal(glossary_term.text_name, glossary_term.name)
  end

  def test_format_name
    glossary_term = glossary_terms(:conic_glossary_term)
    assert_equal(glossary_term.format_name, glossary_term.name)
  end

  def test_add_image_nil
    glossary_term = glossary_terms(:conic_glossary_term)
    image = glossary_term.thumb_image
    images = glossary_term.images
    assert(image)
    assert_equal(1, images.length)
    glossary_term.add_image(nil)
    assert_equal(image, glossary_term.thumb_image)
    assert_equal(1, glossary_term.images.length)
  end

  def test_add_image_additional
    glossary_term = glossary_terms(:conic_glossary_term)
    image = glossary_term.thumb_image
    assert(image)
    images_length = glossary_term.images.length
    additional_image = images(:convex_image)
    glossary_term.add_image(additional_image)
    glossary_term.reload
    assert_equal(image, glossary_term.thumb_image)
    assert_equal(1, glossary_term.images.length - images_length)
    assert(glossary_term.images.member?(additional_image))
  end

  def test_add_image_first
    glossary_term = glossary_terms(:convex_glossary_term)
    assert_nil(glossary_term.thumb_image)
    assert_equal(0, glossary_term.images.length)
    first_image = images(:convex_image)
    glossary_term.add_image(first_image)
    assert_equal(first_image, glossary_term.thumb_image)
    assert_equal(1, glossary_term.images.length)
  end

  def test_add_image_second
    glossary_term = glossary_terms(:conic_glossary_term)
    thumb = glossary_term.thumb_image
    assert(thumb)
    assert_equal(1, glossary_term.images.length)
    second_image = images(:convex_image)
    glossary_term.add_image(second_image)
    assert_equal(thumb, glossary_term.thumb_image)
    assert_equal(2, glossary_term.images.length)
    assert(glossary_term.images.member?(second_image))
  end

  def test_rss_log
    assert(GlossaryTerm.has_rss_log?)
    glossary_term = glossary_terms(:convex_glossary_term)
    assert(glossary_term.has_rss_log?)
  end

  def test_remove_image_thumb
    glossary_term = glossary_terms(:plane_glossary_term)
    thumb = glossary_term.thumb_image
    assert(thumb)
    images_length = glossary_term.images.length
    next_thumb = glossary_term.images[0]
    assert(next_thumb)
    glossary_term.remove_image(thumb)
    glossary_term.reload
    assert_not_equal(thumb, glossary_term.thumb_image)
    assert_equal(next_thumb, glossary_term.thumb_image)
    assert_equal(images_length - 1, glossary_term.images.length)
  end

  def test_remove_image_non_thumb
    glossary_term = glossary_terms(:plane_glossary_term)
    thumb = glossary_term.thumb_image
    assert(thumb)
    images_length = glossary_term.images.length
    first_non_thumb = glossary_term.images[0]
    assert(first_non_thumb)
    glossary_term.remove_image(first_non_thumb)
    glossary_term.reload
    assert_equal(thumb, glossary_term.thumb_image)
    assert_equal(images_length - 1, glossary_term.images.length)
  end

  def test_remove_image_nil
    glossary_term = glossary_terms(:plane_glossary_term)
    thumb = glossary_term.thumb_image
    assert(thumb)
    images_length = glossary_term.images.length
    glossary_term.remove_image(nil)
    glossary_term.reload
    assert_equal(thumb, glossary_term.thumb_image)
    assert_equal(images_length, glossary_term.images.length)
  end

  def test_remove_image_other
    glossary_term = glossary_terms(:plane_glossary_term)
    thumb = glossary_term.thumb_image
    assert(thumb)
    images_length = glossary_term.images.length
    glossary_term.remove_image(images(:conic_image))
    glossary_term.reload
    assert_equal(thumb, glossary_term.thumb_image)
    assert_equal(images_length, glossary_term.images.length)
  end

  def test_validations
    term = GlossaryTerm.new(name: nil, description: "xxx")
    assert(term.invalid?, "GlossaryTerm must have a name")

    term = GlossaryTerm.new(name: GlossaryTerm.first.name,
                            description: "xxx")
    assert(term.invalid?, "GlossaryTerm name must be unique")

    term = GlossaryTerm.new(name: "xxx", description: nil, thumb_image: nil)
    assert(term.invalid?, "GlossaryTerm must have description or image")
  end

  def test_destroy_orphans_log
    term = glossary_terms(:conic_glossary_term)
    log = term.rss_log
    assert_not_nil(log)
    term.destroy!
    assert_nil(log.reload.target_id)
  end

  # Remove an image from images
  # Remove nil
  # Remove an image that is not associated with this glossary_term
end
