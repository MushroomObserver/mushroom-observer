# frozen_string_literal: true

require("test_helper")

class HelpBlockTest < ComponentTestCase
  def test_plain_block_with_string
    html = render(Components::HelpBlock.new(:p, "Help text"))

    # Default plain shape: a `help-block`-classed element (caller picks
    # the tag via the first positional arg).
    assert_html(html, "p.help-block", text: "Help text")
  end

  def test_plain_block_with_block_content
    html = render(Components::HelpBlock.new(:div)) { "From block" }

    # Block-form content takes precedence over the `string:` slot.
    assert_html(html, "div.help-block", text: "From block")
  end

  def test_well_wraps_in_bootstrap_well
    html = render(Components::HelpBlock.new(:p, "Help", well: true))

    # The `well:` flavour wraps content in a Bootstrap well; the
    # element kwarg is intentionally ignored for the well shape.
    assert_html(html, "div.well.well-sm.help-block.position-relative",
                text: "Help")
  end

  def test_arrow_implies_well_and_adds_arrow_div
    html = render(Components::HelpBlock.new(:div, "Help", arrow: :up))

    # Setting `arrow:` is the legacy `help_block_with_arrow` shape —
    # always a well, with an `arrow-up`/`arrow-down` sibling. `mt-3`
    # is added on the up-pointing variant to leave room above for the
    # arrow tip.
    assert_html(html, "div.well.help-block.mt-3", text: "Help")
    assert_html(html, "div.arrow-up.hidden-xs")
  end

  def test_arrow_down_omits_mt3
    html = render(Components::HelpBlock.new(:div, "Help", arrow: :down))

    # Down arrows hang below the well — no leading `mt-3`.
    assert_no_html(html, "div.mt-3")
    assert_html(html, "div.arrow-down.hidden-xs")
  end

  def test_extra_class_appended_to_plain_block
    html = render(Components::HelpBlock.new(:p, "Help", class: "extra-thing"))

    assert_html(html, "p.help-block.extra-thing", text: "Help")
  end

  def test_id_and_extra_attrs_passed_through
    html = render(Components::HelpBlock.new(
                    :div, "Help", id: "h1", data: { x: "v" }
                  ))

    # id and arbitrary data-* asserted independently so renaming
    # the wrapper element or reshuffling attribute order doesn't
    # mass-fail this test.
    assert_html(html, "div.help-block", text: "Help")
    assert_html(html, "div#h1")
    assert_html(html, "div[data-x='v']")
  end

  def test_renders_nothing_when_neither_string_nor_block
    # Empty wrappers are noise the form layout doesn't need; the
    # component bails out when given neither content source.
    html = render(Components::HelpBlock.new(:p))

    assert_equal("", html.to_s.strip)
  end

  def test_collapse_id_wraps_well_in_collapse_div
    # `collapse_id:` is the form-page "click the question icon to
    # reveal help" shape. The collapse wrapper takes the id; an
    # external `data-target="#<id>"` trigger toggles its
    # `.collapse` visibility class.
    html = render(Components::HelpBlock.new(
                    collapse_id: "field_help_x"
                  )) { "Help" }

    assert_html(html, "div.collapse#field_help_x > " \
                      "div.well.help-block", text: "Help")
  end

  def test_collapse_id_implies_well_even_without_explicit_kwarg
    html = render(Components::HelpBlock.new(collapse_id: "x")) { "h" }

    # No need to pass `well: true` alongside `collapse_id:` — the
    # collapse markup only makes sense around a well.
    assert_html(html, "div.collapse > div.well")
  end
end
