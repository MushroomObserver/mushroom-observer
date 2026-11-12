# frozen_string_literal: true

require "test_helper"

module Views::Controllers::SpeciesLists::Observations
  class FormTest < ComponentTestCase
    def test_small_query_no_confirm
      html = render_form(num_results: 1)

      assert_no_html(html, "[data-turbo-confirm]")
    end

    def test_large_query_requires_confirm
      html = render_form(num_results: MO.max_species_list_bulk_edit + 1)

      assert_html(html, "[data-turbo-confirm]", count: 2)
    end

    private

    def render_form(num_results:)
      render(Form.new(num_results: num_results))
    end
  end
end
