# frozen_string_literal: true

require("test_helper")

module Herbaria
  # Display selected Herbaria based on current Query
  class NextsControllerTest < FunctionalTestCase
    # ---------- Actions to Display data (index, show, etc.) -------------------
    def test_next_and_prev
      query = Query.lookup_and_save(:Herbarium, :all)
      assert_operator(query.num_results, :>, 1)
      number1 = query.results[0]
      number2 = query.results[1]
      q = query.record.id.alphabetize

      get(:show, params: { id: number1.id, q: q })
      assert_redirected_to(herbarium_path(number2, q: q))
    end
  end
end
