# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::NameSuggestionsAlertTest <
  ComponentTestCase
  def test_zero_count_links_to_name_show
    name = names(:fungi)
    html = render(
      Views::Controllers::Observations::Show::NameSuggestionsAlert.new(
        names: { name => 0 }
      )
    )

    assert_html(html, "div.alert-warning")
    # Zero-count → name show link, NOT observations search.
    assert_html(html, "a[href='#{routes.name_path(name.id)}']")
    assert_no_html(html, "a[href*='observations?pattern=']")
    assert_includes(html, "(0)")
  end

  def test_nonzero_count_links_to_observations_search
    name = names(:fungi)
    html = render(
      Views::Controllers::Observations::Show::NameSuggestionsAlert.new(
        names: { name => 7 }
      )
    )

    expected_href = routes.observations_path(pattern: name.text_name)
    assert_html(html, "a[href='#{expected_href}']")
    assert_no_html(html, "a[href='#{routes.name_path(name.id)}']")
    assert_includes(html, "(7)")
  end
end
