# frozen_string_literal: true

require("test_helper")

module Herbaria
  # Display selected Herbaria based on current Query
  class NonpersonalsControllerTest < FunctionalTestCase
    # ---------- Actions to Display data (index, show, etc.) -------------------
    def test_index_nonpersonal_herbaria
      get(:index)

      assert_select("#title-caption", text: :query_title_nonpersonal.l)
      Herbarium.where(personal_user_id: nil).each do |herbarium|
        assert_select(
          "a[href ^= '#{herbarium_path(herbarium)}']", true,
          "List of Institutional Fungaria is missing a link to " \
          "#{herbarium.format_name})"
        )
      end
      Herbarium.where.not(personal_user_id: nil).each do |herbarium|
        assert_select(
          "a[href ^= '#{herbarium_path(herbarium)}']", false,
          "List of Institutional Fungaria should not have a link to " \
          "#{herbarium.format_name})"
        )
      end
    end
  end
end
