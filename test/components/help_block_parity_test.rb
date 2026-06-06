# frozen_string_literal: true

require("test_helper")

# HTML parity test: `Components::HelpBlock` (which consolidates the
# legacy `help_block` + `help_block_with_arrow` helpers) vs verbatim
# copies of those helper bodies. Pins behavior so the component-side
# refactor stays byte-equivalent to the markup callers were getting
# from the ERB era.
class HelpBlockParityTest < ComponentTestCase
  include Rails::Dom::Testing::Assertions::DomAssertions

  def test_plain_string_matches_legacy_help_block
    assert_dom_equal(
      legacy_help_block(:p, "Help text"),
      render(Components::HelpBlock.new(:p, "Help text"))
    )
  end

  def test_plain_block_form_matches_legacy_help_block
    legacy = legacy_help_block(:div) { "From block" }
    new_html = render(Components::HelpBlock.new(:div)) { "From block" }

    assert_dom_equal(legacy, new_html)
  end

  def test_extra_class_passed_through_matches_legacy
    assert_dom_equal(
      legacy_help_block(:p, "Help", class: "extra-thing"),
      render(Components::HelpBlock.new(:p, "Help", class: "extra-thing"))
    )
  end

  def test_arrow_up_matches_legacy_help_block_with_arrow
    legacy = legacy_help_block_with_arrow("up") { "Help" }
    new_html = render(Components::HelpBlock.new(:div, arrow: :up)) { "Help" }

    assert_dom_equal(legacy, new_html)
  end

  def test_arrow_down_matches_legacy_help_block_with_arrow
    legacy = legacy_help_block_with_arrow("down") { "Help" }
    new_html = render(Components::HelpBlock.new(:div, arrow: :down)) { "Help" }

    assert_dom_equal(legacy, new_html)
  end

  def test_well_no_arrow_matches_legacy
    # Block form with `well: true` and no arrow — historical
    # `help_block_with_arrow(nil) { ... }` shape.
    legacy = legacy_help_block_with_arrow(nil) { "Help" }
    new_html = render(Components::HelpBlock.new(:div, well: true)) { "Help" }

    assert_dom_equal(legacy, new_html)
  end

  private

  # Inlined copy of the pre-Phlex `PanelHelper#help_block` body.
  def legacy_help_block(element = :div, string = "", **args, &block)
    content = block ? view_context.capture(&block) : string
    html_options = {
      class: ["help-block", args[:class]].compact.join(" ")
    }.deep_merge(args.except(:class))

    view_context.content_tag(element, html_options) { content }
  end

  # Inlined copy of the pre-Phlex `PanelHelper#help_block_with_arrow`
  # body.
  def legacy_help_block_with_arrow(direction = nil, **args, &block)
    div_class = "well well-sm mb-3 help-block position-relative"
    div_class += " mt-3" if direction == "up"

    view_context.tag.div(class: div_class, id: args[:id]) do
      content = view_context.capture(&block).to_s
      arrow = if direction
                view_context.tag.div("",
                                     class: "arrow-#{direction} hidden-xs")
              else
                ""
              end
      (content + arrow.to_s).html_safe # rubocop:disable Rails/OutputSafety
    end
  end
end
