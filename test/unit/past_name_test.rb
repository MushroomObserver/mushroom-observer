require File.dirname(__FILE__) + '/../test_helper'

class PastNameTest < Test::Unit::TestCase
  fixtures :past_names

  # Replace this with your real tests.
  def test_truth
    assert_kind_of PastName, @coprinus_comatus
  end
end
