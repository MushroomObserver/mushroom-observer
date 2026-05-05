# frozen_string_literal: true

require "test_helper"

class PrintLabelsFormTest < ComponentTestCase
  def test_form_structure
    html = render_form

    assert_html(html, "form#species_list_download_print_labels")
    assert_html(html, "form[action*='print_labels']" \
                      "[action*='q=abc123']")
    assert_includes(html, "#{:species_list_labels_header.l}:")
    assert_html(
      html,
      "input[type='submit']" \
      "[value='#{:species_list_labels_button.l}']" \
      "[class*='center-block']"
    )
  end

  private

  def render_form(query_param: "abc123")
    render(Components::PrintLabelsForm.new(query_param: query_param))
  end
end
