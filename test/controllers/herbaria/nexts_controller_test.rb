# frozen_string_literal: true

require("test_helper")

module Herbaria
  # Display selected Herbaria based on current Query
  class NextsControllerTest < FunctionalTestCase
    # ---------- Helpers ----------

    def nybg
      herbaria(:nybg_herbarium)
    end

    # ---------- Actions to Display data (index, show, etc.) -------------------
    def test_show_next
      query = Query.lookup_and_save(:Herbarium, :all)
      assert_operator(query.num_results, :>, 1)
      number1 = query.results[0]
      number2 = query.results[1]
      q = query.record.id.alphabetize

      login
      get(:show, params: { id: number1.id, q: q, next: "next" })
      assert_redirected_to(herbarium_path(number2, q: q))
    end

    def test_show_prev
      query = Query.lookup_and_save(:Herbarium, :all)
      assert_operator(query.num_results, :>, 1)
      number1 = query.results[0]
      number2 = query.results[1]
      q = query.record.id.alphabetize

      login
      get(:show, params: { id: number2.id, q: q, next: "prev" })
      assert_redirected_to(herbarium_path(number1, q: q))
    end

    def test_show_no_direction
      get(:show, params: { id: nybg.id })
      assert_redirected_to(herbarium_path(nybg))
    end
  end
end
