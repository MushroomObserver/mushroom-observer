# frozen_string_literal: true

require("test_helper")

module Herbaria
  # Display selected Herbaria based on current Query
  class FilteredsControllerTest < FunctionalTestCase
    # ---------- Helpers ----------

    def nybg
      herbaria(:nybg_herbarium)
    end

    # ---------- Actions to Display data (index, show, etc.) -------------------
    def test_filtered_no_query
      get(:index)

      assert_response(:success)
      Herbarium.find_each do |herbarium|
        assert_select(
          "a[href *= '#{herbarium_path(herbarium)}']", true,
          "Herbarium Index missing link to #{herbarium.format_name})"
        )
      end
    end

    def test_filtered_all
      Query.lookup_and_save(:Herbarium, :all)
      get(:index)

      assert_response(:success)
      Herbarium.find_each do |herbarium|
        assert_select(
          "a[href *= '#{herbarium_path(herbarium)}']", true,
          "Herbarium Index missing link to #{herbarium.format_name})"
        )
      end
    end

    def test_filtered_set
      skip "under construction"
      set = [nybg, herbaria(:rolf_herbarium)]
      Query.lookup_and_save(:Herbarium, :in_set, by: :name, ids: set)
      get(:index, params: { id: nybg.id })

      assert_response(:success)
      assert_select(
        "a:match('href', ?)", %r{^#{herbaria_path}/(\d+)}, { count: set.size },
        "Filtered index should have exactly one link to each herbarium"
      )
    end
  end
end
