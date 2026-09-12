# frozen_string_literal: true

require("test_helper")

# Tests for Components::ApplicationForm::RadioField -- both the
# `radio_field` ApplicationForm helper (via a real form/model) and
# the per-choice opts extensions (disabled / append / label_block)
# via a bare FieldProxy.
class RadioFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Radio field tests (via Superform)
  def test_radio_field_renders_options
    form = render_form do
      radio_field(:number, [1, "Option 1"], [2, "Option 2"])
    end

    assert_html(form, "div.radio")
    assert_html(form, "input[type='radio'][name='collection_number[number]']",
                count: 2)
    assert_html(form, "input[value='1']")
    assert_html(form, "input[value='2']")
    assert_includes(form, "Option 1")
    assert_includes(form, "Option 2")
  end

  def test_radio_field_with_wrap_class
    form = render_form do
      radio_field(:number, [1, "A"], [2, "B"], wrap_class: "ml-4")
    end

    assert_html(form, "div.radio.ml-4", count: 2)
  end

  # Regression: each per-option label carries `for=` pointing at its
  # input's id (matching ERB radio_with_label, which uses
  # form.label("#{field}_#{value}")).
  def test_radio_field_per_option_label_has_for_attribute
    form = render_form do
      radio_field(:number, [1, "A"], [2, "B"])
    end

    assert_html(form, "label[for='collection_number_number_1']")
    assert_html(form, "label[for='collection_number_number_2']")
    assert_html(form, "input[type='radio'][id='collection_number_number_1']")
    assert_html(form, "input[type='radio'][id='collection_number_number_2']")
  end

  # Regression: RadioField `between` slot renders after each option's
  # label text inside the `<label>`, wrapped in `<div class="d-inline-block
  # ml-3">`. Matches ERB `radio_with_label`'s `between:` shape. Applied
  # uniformly to every option (one slot per RadioField call).
  def test_radio_field_with_between_slot
    form = render_form do
      component = Components::ApplicationForm::RadioField.new(
        field(:number), [1, "A"], [2, "B"]
      )
      component.with_between do
        span(class: "help-note") { "(see notes)" }
      end
      render(component)
    end

    assert_html(form, "div.radio div.d-inline-block.ml-3 span.help-note",
                count: 2)
    assert_includes(form, "(see notes)")
  end

  # RadioField standalone tests (via FieldProxy)
  def test_radio_field_with_field_proxy
    proxy = Components::ApplicationForm::FieldProxy.new(
      "chosen_name", :name_id
    )
    html = render_radio_field(proxy, [10, "Alpha"], [20, "Beta"],
                              wrapper_options: { wrap_class: "ml-4" })

    assert_html(html, "div.radio.ml-4", count: 2)
    assert_html(html,
                "input[type='radio'][name='chosen_name[name_id]']",
                count: 2)
    assert_html(html, "input[id='chosen_name_name_id_10'][value='10']")
    assert_html(html, "input[id='chosen_name_name_id_20'][value='20']")
    assert_includes(html, "Alpha")
    assert_includes(html, "Beta")
  end

  def test_radio_field_proxy_with_checked_value
    proxy = Components::ApplicationForm::FieldProxy.new(
      "chosen_name", :name_id, "20"
    )
    html = render_radio_field(proxy, [10, "Alpha"], [20, "Beta"])

    assert_html(html, "input[value='10']:not([checked])")
    assert_html(html, "input[value='20'][checked]")
  end

  # Regression test: Symbol option values should be converted to strings
  def test_radio_field_with_symbol_values
    proxy = Components::ApplicationForm::FieldProxy.new(
      "chosen_name", :status, :active
    )
    html = render_radio_field(proxy, [:active, "Active"],
                              [:inactive, "Inactive"])

    # Symbol values should be rendered as strings
    assert_html(html, "input[value='active']")
    assert_html(html, "input[value='inactive']")
    # The active option should be checked (matching Symbol :active)
    assert_html(html, "input[value='active'][checked]")
    assert_html(html, "input[value='inactive']:not([checked])")
  end

  # Regression: RadioField's append slot is per-group, so it lands
  # once after the final <div class="radio"> wrap -- not interleaved
  # with options.
  def test_radio_field_append_slot_renders_after_last_option
    form = render_comment_form do
      radio_field(:summary, [1, "One"], [2, "Two"], [3, "Three"]) do |f|
        f.with_append { div(class: "after-radios") { "after the group" } }
      end
    end

    radios = form.scan('<div class="radio">')
    assert_equal(3, radios.size, "expected 3 radio option wraps")

    last_radio_end = form.rindex("</div>", form.index("after-radios"))
    assert(last_radio_end,
           "append content should be emitted after the radio group")
    assert_html(form, "div.after-radios", text: "after the group")
  end

  def test_radio_field_symbol_with_value_selects_non_model_attribute
    form = render_comment_form do
      radio_field(:target_id, [1, "One"], [2, "Two"], value: 2,
                                                      label: "Target:")
    end

    assert_html(form,
                "input[type='radio'][name='comment[target_id]']" \
                "[value='2'][checked]")
    assert_html(form,
                "input[type='radio'][name='comment[target_id]']" \
                "[value='1']:not([checked])")
  end

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

  def test_per_choice_append_accepts_proc
    append_block = -> { a(href: "/from_proc") { "Create" } }
    html = render_field([
                          [1, "A"],
                          [2, "B", { append: append_block }]
                        ])

    # Proc invoked in RadioField's Phlex render context — sibling of
    # the label, inside .radio, just like the SafeBuffer form.
    assert_html(html, ".radio > a[href='/from_proc']", text: "Create")
    assert_no_html(html, "label[for='target_2'] a[href='/from_proc']")
  end

  def test_per_choice_nil_opts_tolerated
    # `[value, label, nil]` 3-tuple should be treated the same as
    # `[value, label]` — split_per_choice_opts skips the assignment.
    html = render_field([[1, "A"], [2, "B", nil]])

    assert_html(html, "input[type='radio'][value='1']")
    assert_html(html, "input[type='radio'][value='2']")
    assert_includes(html, "A")
    assert_includes(html, "B")
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
