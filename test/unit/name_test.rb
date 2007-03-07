require File.dirname(__FILE__) + '/../test_helper'

class NameTest < Test::Unit::TestCase
  fixtures :names

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Name, @coprinus_comatus
  end
end
