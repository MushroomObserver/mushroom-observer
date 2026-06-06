# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Namings::FooterLegendTest <
  ComponentTestCase
  def test_renders_two_centered_legend_columns
    # Legend columns sit centered in the leftmost 11 of 12 — the
    # `col-xs-offset-4` on the first col centers the pair.
    html = render_legend

    assert_html(html, ".col-sm-11 > .row > .col-xs-4.col-xs-offset-4")
    assert_html(html, ".col-sm-11 > .row > .col-xs-4:not(.col-xs-offset-4)")
  end

  def test_renders_yours_eye_with_its_help_text
    html = render_legend

    assert_html(html, ".vote-icon-yours")
    assert_includes(html, :show_namings_eye_help.t)
  end

  def test_renders_consensus_eye_with_its_help_text
    html = render_legend

    assert_html(html, ".vote-icon-consensus")
    assert_includes(html, :show_namings_eyes_help.t)
  end

  def test_eye_icons_have_full_three_div_wrapper
    # CSS depends on the triple-nested `vote-icon-width` >
    # `vote-icon-sizer` > `vote-icon-*` shape for centering and
    # sizing.
    html = render_legend

    assert_html(html,
                ".vote-icon-width > .vote-icon-sizer > .vote-icon-yours")
    assert_html(html, ".vote-icon-width > .vote-icon-sizer > " \
                      ".vote-icon-consensus")
  end

  private

  def render_legend
    render(Views::Controllers::Observations::Show::Namings::FooterLegend.new)
  end
end
