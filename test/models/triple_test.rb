# frozen_string_literal: true

require "test_helper"

class TripleTest < UnitTestCase
  def test_delete_predicate_matches
    Triple.delete_predicate_matches(":somePredicate")
  end
end
