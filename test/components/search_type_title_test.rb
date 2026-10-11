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

  # `disabled` has no effect on an `<a>` -- the active item is still
  # clickable, so it must not carry the chooser action too, or
  # clicking it would trigger a pointless refetch of the same form.
  def test_active_item_has_no_chooser_action
    html = render_title(current_type: :observations)

    assert_no_html(html, "#search_type_menu a.active[data-action]")
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

  def test_menu_items_sorted_by_label
    html = render_title(current_type: :observations)

    doc = Nokogiri::HTML(html)
    labels = doc.css("#search_type_menu a").map(&:text)

    assert_equal(labels.sort, labels)
  end

  private

  def render_title(current_type:)
    render(Components::SearchTypeTitle.new(current_type: current_type))
  end
end
