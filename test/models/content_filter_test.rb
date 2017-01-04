# encoding: utf-8
require "test_helper"

class ContentFilterTest < UnitTestCase
  def test_filters
    assert_equal(2, ContentFilter.all.length)
    assert_equal(2, ContentFilter.observation_filters.length)
    assert_equal([:has_images, :has_specimen],
                 ContentFilter.observation_filter_keys)
    assert_equal(2, ContentFilter.observation_filters_with_checkboxes.length)
  end

  def test_find
    fltr = ContentFilter.find(:has_images)
    assert_not_nil(fltr)
    assert_equal(:has_images, fltr.sym)
  end
end
