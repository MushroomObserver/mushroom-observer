require File.dirname(__FILE__) + '/../test_helper'

class CommentTest < Test::Unit::TestCase
  fixtures :comments

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Comment, comments(:first)
  end
end
