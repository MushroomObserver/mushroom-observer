require File.dirname(__FILE__) + '/../test_helper'

class ImageTest < Test::Unit::TestCase
  fixtures :images

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Image, images(:first)
  end
end
