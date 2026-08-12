# frozen_string_literal: true

require("test_helper")

module Views::Controllers::SpeciesLists::Downloads
  class FormTest < ComponentTestCase
    def test_form_structure
      html = render_form

      assert_html(html, "form#species_list_download_print_labels")
      assert_html(html, "form[action*='print_labels']" \
                        "[action*='q%5Bmodel%5D=Observation']")
      assert_includes(html, "#{:species_list_labels_header.l}:")
      assert_html(html, "button[type='submit']",
                  text: :species_list_labels_button.l)
    end

    private

    def render_form(query_param: { model: :Observation })
      render(Form.new(query_param: query_param))
    end
  end
end
