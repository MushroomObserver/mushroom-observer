# frozen_string_literal: true

require("test_helper")

class SearchTypeTitleTest < ComponentTestCase
  def test_renders_current_type_as_toggle
    html = render_title(current_type: :observations)

    assert_html(html, "#search_type_toggle", text: :observations.ti)
  end

  def test_current_type_is_active_and_disabled_in_menu
    html = render_title(current_type: :observations)

    assert_html(html, "#search_type_menu a.active[disabled]",
                text: :observations.ti)
  end

  def test_other_types_link_to_their_search_form_with_chooser_action
    html = render_title(current_type: :observations)

    assert_html(
      html,
      "#search_type_menu a[href='/names/search/new']" \
      "[data-action='search-type#chooseType'][data-type='names']",
      text: :names.ti
    )
    assert_no_html(html, "#search_type_menu a.active", text: :names.ti)
  end

  private

  def render_title(current_type:)
    render(Components::SearchTypeTitle.new(current_type: current_type))
  end
end
