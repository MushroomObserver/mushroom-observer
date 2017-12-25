# encoding: utf-8
require "test_helper"

class ContentFilterTest < UnitTestCase
  def test_filters
    assert_equal([:has_images, :has_specimen, :lichen, :region, :clade],
                 ContentFilter.all.map(&:sym))
    assert_equal([:region],
                 ContentFilter.by_model(Location).map(&:sym))
    assert_equal([:lichen, :clade],
                 ContentFilter.by_model(Name).map(&:sym))
  end

  def test_find
    fltr = ContentFilter.find(:has_images)
    assert_not_nil(fltr)
    assert_equal(:has_images, fltr.sym)
  end
end
