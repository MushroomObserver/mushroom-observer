# frozen_string_literal: true

require("test_helper")

class HelpTest < ComponentTestCase
  # rubocop:disable-next MO/RedundantTagInSelector
  def test_plain_block_with_string
    html = render_help(element: :p, content: "Help text")

    # Default plain shape: a `help-block form-text`-classed element.
    assert_html(html, "p.help-block.form-text", text: "Help text")
  end

  def test_plain_block_with_block_content
    html = render_help(element: :div) { "From block" }

    # Block-form content takes precedence over `content:`.
    assert_html(html, ".help-block.form-text", text: "From block")
  end

  # rubocop:disable-next MO/RedundantTagInSelector
  def test_content_only_uses_default_div_element
    html = render_help(content: "Help text")

    assert_html(html, "div.help-block.form-text", text: "Help text")
  end

  # The `well:` flavour wraps content in a Bootstrap well; the
  # element kwarg is intentionally ignored for the well shape --
  # it always renders as a div regardless of the `:p` passed in.
  # rubocop:disable-next MO/RedundantTagInSelector
  def test_well_wraps_in_bootstrap_well
    html = render_help(element: :p, content: "Help", well: true)

    # The `well:` flavour wraps content in a Well; the element kwarg
    # is intentionally ignored for the well shape.
    assert_html(html, "div.well.help-block.position-relative",
                text: "Help")
  end

  # Setting `arrow:` is the legacy `help_block_with_arrow` shape —
  # always a well, with an `arrow-up`/`arrow-down` sibling matching
  # the direction passed in.
  def test_arrow_up_renders_arrow_up_sibling
    html = render_help(element: :div, content: "Help", arrow: :up)

    # Setting `arrow:` is the legacy `help_block_with_arrow` shape —
    # always a well, with an `arrow-up`/`arrow-down` sibling.
    assert_html(html, ".well.help-block", text: "Help")
    hide_classes = Components::Column.mobile_hide_classes.join(".")
    assert_html(html, ".arrow-up.#{hide_classes}")
  end

  def test_arrow_down_renders_arrow_down_sibling
    html = render_help(element: :div, content: "Help", arrow: :down)

    hide_classes = Components::Column.mobile_hide_classes.join(".")
    assert_html(html, ".arrow-down.#{hide_classes}")
  end

  def test_extra_class_appended_to_plain_block
    html = render_help(element: :p, content: "Help", class: "extra-thing")

    assert_html(html, ".help-block.form-text.extra-thing", text: "Help")
  end

  def test_id_and_extra_attrs_passed_through
    html = render_help(element: :div, content: "Help",
                       id: "custom-help-id", data: { x: "v" })

    # id and arbitrary data-* asserted independently so renaming
    # the wrapper element or reshuffling attribute order doesn't
    # mass-fail this test.
    assert_html(html, ".help-block.form-text", text: "Help")
    assert_html(html, "#custom-help-id")
    assert_html(html, "[data-x='v']")
  end

  def test_renders_nothing_when_neither_content_nor_block
    # Empty wrappers are noise the form layout doesn't need; the
    # component bails out when given neither content source.
    html = render_help(element: :p)

    assert_equal("", html.to_s.strip)
  end

  def test_collapse_id_wraps_well_in_collapse_div
    # `collapse_id:` is the form-page "click the question icon to
    # reveal help" shape. The collapse wrapper takes the id; an
    # external `data-target="#<id>"` trigger toggles its
    # `.collapse` visibility class.
    html = render_help(collapse_id: "field_help_x") { "Help" }

    assert_html(html, ".collapse#field_help_x > " \
                      ".well.help-block", text: "Help")
  end

  def test_collapse_id_implies_well_even_without_explicit_kwarg
    html = render_help(collapse_id: "x") { "h" }

    # No need to pass `well: true` alongside `collapse_id:` — the
    # collapse markup only makes sense around a well.
    assert_html(html, ".collapse > .well")
  end

  # ----- element: :span (the "help-note" flavor) -----
  #
  # `.help-block` carries `.form-text` (BS4's `display: block` +
  # top-margin class), so reusing it for `element: :span` content
  # would force a line-break regardless of the `<span>` tag.
  # `render_plain` picks `.help-note` for `:span` and `.help-block
  # form-text` for everything else to keep the inline shape inline.

  # rubocop:disable-next MO/RedundantTagInSelector
  def test_span_element_renders_help_note_class
    html = render_help(element: :span, content: "(optional)")

    assert_html(html, "span.help-note", text: "(optional)")
  end

  # rubocop:disable-next MO/RedundantTagInSelector
  def test_span_block_form_renders_block_content
    html = render_help(element: :span) { "From block" }

    assert_html(html, "span.help-note", text: "From block")
  end

  def test_span_extra_class_and_attrs_pass_through
    html = render_help(element: :span, content: "x",
                       class: "extra-thing", id: "h", data: { foo: "bar" })

    assert_html(html, "span#h.help-note.extra-thing")
    assert_html(html, "span[data-foo='bar']")
  end

  private

  def render_help(**, &block)
    render(Components::Help.new(**), &block)
  end
end
