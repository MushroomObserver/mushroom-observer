# frozen_string_literal: true

require "test_helper"

class CollapseHelpBlockTest < ComponentTestCase
  def test_renders_basic_collapse_block_with_content
    html = render_component(
      Components::CollapseHelpBlock.new(target_id: "help_1")
    ) { "This is help text" }

    assert_html(html, "div.collapse#help_1")
    assert_html(html, "div.well.well-sm.mb-3.help-block.position-relative")
    assert_html(html, "div.collapse#help_1", text: "This is help text")
  end

  def test_renders_without_arrow_when_direction_nil
    html = render_component(
      Components::CollapseHelpBlock.new(target_id: "help_2")
    ) { "Content" }

    assert_html(html, "div.collapse#help_2")
    assert_not_includes(html, "arrow-")
  end

  def test_renders_with_arrow_down_when_direction_down
    html = render_component(
      Components::CollapseHelpBlock.new(target_id: "help_3", direction: "down")
    ) { "Content" }

    assert_html(html, "div.arrow-down.hidden-xs")
    assert_not_includes(html, "mt-3")
  end

  def test_renders_with_arrow_up_when_direction_up
    html = render_component(
      Components::CollapseHelpBlock.new(target_id: "help_4", direction: "up")
    ) { "Content" }

    assert_html(html, "div.arrow-up.hidden-xs")
    assert_html(html, "div.well.well-sm.mb-3.help-block.position-relative.mt-3")
  end

  def test_renders_arrow_visible_on_mobile_when_mobile_true
    html = render_component(
      Components::CollapseHelpBlock.new(
        target_id: "help_5",
        direction: "up",
        mobile: true
      )
    ) { "Mobile content" }

    assert_html(html, "div.arrow-up")
    assert_not_includes(html, "hidden-xs")
  end

  def test_renders_arrow_hidden_on_mobile_when_mobile_false
    html = render_component(
      Components::CollapseHelpBlock.new(
        target_id: "help_6",
        direction: "down",
        mobile: false
      )
    ) { "Desktop content" }

    assert_html(html, "div.arrow-down.hidden-xs")
  end

  def test_yields_block_content
    html = render_component(
      Components::CollapseHelpBlock.new(target_id: "help_7")
    ) do
      "Custom <strong>HTML</strong> content"
    end

    assert_includes(html, "Custom &lt;strong&gt;HTML&lt;/strong&gt; content")
  end

  def test_multiple_directions_with_mobile_combinations
    # Test left arrow with mobile
    html_left = render_component(
      Components::CollapseHelpBlock.new(
        target_id: "help_8",
        direction: "left",
        mobile: true
      )
    ) { "Left" }
    assert_html(html_left, "div.arrow-left")
    assert_not_includes(html_left, "hidden-xs")

    # Test right arrow without mobile
    html_right = render_component(
      Components::CollapseHelpBlock.new(
        target_id: "help_9",
        direction: "right",
        mobile: false
      )
    ) { "Right" }
    assert_html(html_right, "div.arrow-right.hidden-xs")
  end
end
