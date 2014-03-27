require 'test_helper'

class TripleTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end

  def test_delete_predicate_matches
    Triple.delete_predicate_matches(':somePredicate')
  end
end
