require File.dirname(__FILE__) + '/../test_helper'

class SynonymTest < Test::Unit::TestCase
  fixtures :synonyms

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Synonym, @chlorophyllum_rachodes_synonym
  end
end
