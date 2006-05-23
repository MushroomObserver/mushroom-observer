require File.dirname(__FILE__) + '/../test_helper'

class ImageTest < Test::Unit::TestCase
  fixtures :images

  def setup
    @is = Image.find(1)
    @to = Image.find(2)
  end

  # Replace this with your real tests.
  def test_create
    assert_kind_of Image, @is
    assert_equal @in_situ.id, @is.id
    assert_equal @in_situ.created, @is.created
    assert_equal @in_situ.modified, @is.modified
    assert_equal @in_situ.content_type, @is.content_type
    assert_equal @in_situ.title, @is.title
    assert_equal @in_situ.owner, @is.owner
    assert_equal @in_situ.when, @is.when
    assert_equal @in_situ.notes, @is.notes
  end
end
