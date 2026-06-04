# frozen_string_literal: true

require("test_helper")
require_relative("parity_helper")

class Views::Controllers::Observations::Show::NameSuggestionsAlertTest <
  ComponentTestCase
  include Views::Controllers::Observations::Show::ParityHelper

  def test_zero_count_links_to_name_show
    name = names(:fungi)
    html = render(alert_with(names: [[name, 0]]))

    assert_html(html, "div.alert-warning")
    assert_html(html, "a[href='#{routes.name_path(name.id)}']")
    assert_no_html(html, "a[href*='observations?pattern=']")
    assert_includes(html, "(0)")
  end

  def test_nonzero_count_links_to_observations_search
    name = names(:fungi)
    html = render(alert_with(names: [[name, 7]]))

    expected_href = routes.observations_path(pattern: name.text_name)
    assert_html(html, "a[href='#{expected_href}']")
    assert_no_html(html, "a[href='#{routes.name_path(name.id)}']")
    assert_includes(html, "(7)")
  end

  def test_parity_mixed_counts
    pairs = [[names(:fungi), 0], [names(:agaricus), 3]]

    erb_html = render_legacy_erb("name_suggestions", names: pairs)
    phlex_html = render(alert_with(names: pairs))

    assert_html_element_equivalent(
      erb_html, phlex_html, selector: ".alert-warning",
                            label: "name_suggestions mixed counts"
    )
  end

  private

  def alert_with(names:)
    Views::Controllers::Observations::Show::NameSuggestionsAlert.new(
      names: names
    )
  end
end
