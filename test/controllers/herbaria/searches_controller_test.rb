# frozen_string_literal: true

require("test_helper")

# tests Herbaria pattern searches
module Herbaria
  class SearchesControllerTest < FunctionalTestCase
    # ---------- Helpers ----------

    def nybg
      herbaria(:nybg_herbarium)
    end

    # ---------- Tests ----------

    def test_text_pattern
      pattern = "Personal Herbarium"
      get(:index, params: { pattern: pattern })

      assert_select("#title-caption").text.start_with?(
        :query_title_pattern_search.l(types: :HERBARIA.l, pattern: pattern)
      )
      Herbarium.where.not(personal_user_id: nil).each do |herbarium|
        assert_select(
          "a[href ^= '#{herbarium_path(herbarium)}']", true,
          "Search for #{pattern} is missing a link to " \
          "#{herbarium.format_name})"
        )
      end
      Herbarium.where(personal_user_id: nil).each do |herbarium|
        assert_select(
          "a[href ^= '#{herbarium_path(herbarium)}']", false,
          "Search for #{pattern} should not have a link to " \
          "#{herbarium.format_name})"
        )
      end
    end

    def test_integer_pattern
      get(:index, params: { pattern: nybg.id })

      assert_redirected_to(
        herbarium_path(nybg),
        "Herbarium search for ##{nybg.id} should show #{nybg.name} herbarium"
      )
    end
  end
end
