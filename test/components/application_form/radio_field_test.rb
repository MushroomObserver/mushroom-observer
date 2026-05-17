# frozen_string_literal: true

require("test_helper")

# Tests for Components::ApplicationForm::RadioField — focused on the
# per-choice opts extensions (disabled / append / label_block). Basic
# rendering is covered indirectly by callers (form_carousel_item,
# project_violations_form, etc.).
class RadioFieldTest < ComponentTestCase
  def test_renders_simple_two_tuple_choices
    html = render_field([[1, "Option 1"], [2, "Option 2"]])

    # Each option wrapped in .radio with a label-for matching the radio id.
    assert_html(html, ".radio > label[for='target_1'] > input" \
                      "[type='radio'][name='target'][value='1']")
    assert_html(html, ".radio > label[for='target_2'] > input" \
                      "[type='radio'][name='target'][value='2']")
    assert_includes(html, "Option 1")
    assert_includes(html, "Option 2")
  end

  def test_preselects_choice_matching_field_value
    html = render_field([[1, "A"], [2, "B"]], field_value: 2)

    assert_html(html, "input[value='1']:not([checked])")
    assert_html(html, "input[value='2'][checked]")
  end

  def test_per_choice_disabled_adds_input_attr
    html = render_field([
                          [1, "Enabled"],
                          [2, "Disabled", { disabled: true }]
                        ])

    assert_html(html, "input[value='1']:not([disabled])")
    assert_html(html, "input[value='2'][disabled]")
  end

  def test_per_choice_append_emits_after_label_inside_radio_wrap
    append_html = "<a href='/create'>Create</a>".html_safe
    html = render_field([
                          [1, "A"],
                          [2, "B", { append: append_html }]
                        ])

    # Append rendered as a sibling of the label, inside the .radio wrap,
    # so a click on the link doesn't activate the radio.
    assert_html(html, ".radio > label[for='target_2']")
    assert_html(html, ".radio > a[href='/create']")
    # Sibling, not nested:
    assert_no_html(html, "label[for='target_2'] a[href='/create']")
  end

  def test_per_choice_label_block_replaces_text_label
    block = lambda do
      strong { "Bold part" }
      div(class: "ml-4 text-muted") { "Help text" }
    end
    html = render_field([
                          [1, "Plain text label"],
                          [2, nil, { label_block: block }]
                        ])

    # Option 1 keeps the plain text label.
    assert_includes(html, "Plain text label")
    # Option 2's label content is rendered by the block, inside <label>.
    assert_html(html, "label[for='target_2'] > strong",
                text: "Bold part")
    assert_html(html, "label[for='target_2'] > div.ml-4.text-muted",
                text: "Help text")
  end

  def test_per_choice_label_block_takes_precedence_over_text
    block = -> { span { "From block" } }
    html = render_field([
                          [1, "From text", { label_block: block }]
                        ])

    assert_html(html, "label > span", text: "From block")
    assert_not_includes(html, "From text")
  end

  private

  def render_field(choices, field_value: nil)
    proxy = Components::ApplicationForm::FieldProxy.new(
      nil, "target", field_value
    )
    render(Components::ApplicationForm::RadioField.new(proxy, *choices))
  end
end
