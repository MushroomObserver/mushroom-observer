# frozen_string_literal: true

require "test_helper"

# Tests for the `checkbox_field` ApplicationForm helper.
class CheckboxFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Regression: `prefs_no_emails` ("Opt out of _all_ email from MO.")
  # carries real textile italic markup -- FieldLabelRow#resolved_label_text
  # resolves bare Symbol labels via `.t`, not `.l`, specifically so this
  # renders as an actual <em> tag (MO's Textile class's italic output)
  # instead of literal underscores.
  def test_checkbox_field_prefs_auto_resolves_label_from_i18n
    form = render_form do
      checkbox_field(:no_emails, prefs: true)
    end

    assert_includes(form, "Opt out of")
    assert_html(form, "label em", text: "all")
    assert_no_html(form, "label", text: "_all_")
  end

  # Checkbox field tests - CollectionNumber doesn't have boolean fields,
  # so we'll just test the rendering with a placeholder field
  def test_checkbox_field_renders_with_basic_options
    form = render_form do
      checkbox_field(:placeholder, label: "Test checkbox")
    end

    assert_includes(form, "checkbox")
    assert_includes(form, "Test checkbox")
    assert_includes(form, 'type="checkbox"')
  end

  def test_checkbox_field_with_label_false_still_renders_wrapper
    form = render_form do
      checkbox_field(:placeholder, label: false,
                                   wrap_class: "m-0", label_class: "p-0")
    end

    # Should still have Bootstrap checkbox wrapper and label element
    assert_html(form, "div.checkbox.m-0")
    assert_html(form, "label.p-0")
    assert_includes(form, 'type="checkbox"')
    # But should NOT have label text
    assert_not_includes(form, "Placeholder")
  end

  def test_checkbox_field_applies_wrap_class_to_wrapper
    form = render_form do
      checkbox_field(:placeholder, label: "Test", wrap_class: "mt-3")
    end

    # wrap_class should be on wrapper div, not the input
    assert_html(form, "div.checkbox.mt-3")
  end

  # Unlike text_field/select_field/etc's colon-suffixed prompt label
  # (see test_label_containing_a_link_raises above), a checkbox label
  # can be rich content -- e.g. names/synonyms/form.rb's
  # synonym-selection checkboxes, whose label is a name link plus a
  # copy-id badge. CheckboxField#label_text calls resolved_label_text
  # directly, bypassing FieldLabelRow#label_text's link guard
  # entirely, so this must render without raising.
  def test_checkbox_field_label_with_link_does_not_raise
    form = render_form do
      checkbox_field(:placeholder, label: '<a href="/x">Click</a>'.html_safe)
    end

    assert_html(form, "label a[href='/x']", text: "Click")
  end

  # Collection mode: `checkbox_field(:field, [label, value], ...)`
  # renders N checkboxes that post as `model[field][]=<value>` for
  # each checked option. Pairs are `[label, value]` — matching
  # `select_field` and `radio_field`. Previously this API path was
  # unreachable: callers had to bypass `checkbox_field` and call
  # `field(:foo).checkbox(...)` directly.
  def test_checkbox_field_array_mode_renders_one_checkbox_per_choice
    form = render_form do
      checkbox_field(:placeholder,
                     ["Foo", 1],
                     ["Bar", 2],
                     ["Baz", 3])
    end

    # Each option becomes a checkbox with the field name suffixed `[]`
    # so the controller receives an array of selected values. Values
    # are the SECOND element of each pair (Rails shape).
    name_attr = "#{@collection_number.class.model_name.singular}" \
                "[placeholder][]"
    assert_html(form,
                "input[type='checkbox'][name='#{name_attr}'][value='1']")
    assert_html(form,
                "input[type='checkbox'][name='#{name_attr}'][value='2']")
    assert_html(form,
                "input[type='checkbox'][name='#{name_attr}'][value='3']")
    # Labels (first element of each pair) render alongside each input.
    assert_includes(form, "Foo")
    assert_includes(form, "Bar")
    assert_includes(form, "Baz")
  end

  def test_checkbox_field_with_between_slot
    form = render_form do
      checkbox_field(:placeholder, label: "Test") do |field|
        field.with_between do
          em { "Note" }
        end
      end
    end

    assert_includes(form, "<em>Note</em>")
  end

  # Regression: array-mode checkbox per-option labels also carry `for=`,
  # AND the inputs get value-suffixed ids (so multiple options don't
  # collide). MO's CheckboxField bypasses upstream's Checkbox component
  # for this case because upstream mis-detects array mode when the
  # field's parent isn't another Superform::Field. Array mode is reached
  # via `field(:foo).checkbox([v, label], …)` directly.
  def test_checkbox_field_array_mode_per_option_label_has_for_attribute
    form = render_form do
      # Rails-shape pairs: `[label, value]` (matches `select_field`).
      render(field(:number).checkbox(["A", 1], ["B", 2]))
    end

    assert_html(form, "label[for='collection_number_number_1']")
    assert_html(form, "label[for='collection_number_number_2']")
    assert_html(form, "input[type='checkbox'][id='collection_number_number_1']")
    assert_html(form, "input[type='checkbox'][id='collection_number_number_2']")
    # Each option submits its own value under `field[]`
    array_name = "collection_number[number][]"
    assert_html(form,
                "input[type='checkbox'][name='#{array_name}'][value='1']")
    assert_html(form,
                "input[type='checkbox'][name='#{array_name}'][value='2']")
  end

  # Regression: checkbox_field's unchecked-value hidden sidecar carries
  # autocomplete="off", matching Rails form.check_box -- otherwise
  # browsers restore "0" on back-button and silently clobber a checked
  # box.
  def test_checkbox_field_hidden_sidecar_has_autocomplete_off
    form = render_comment_form { checkbox_field(:ok, label: "OK?") }

    assert_html(form,
                "input[type='hidden'][name='comment[ok]']" \
                "[value='0'][autocomplete='off']")
    assert_html(form, "input[type='checkbox'][name='comment[ok]']" \
                      "[value='1']")
  end

  def test_checkbox_field_accepts_string_name
    form = render_comment_form do
      checkbox_field("member[specimen]", value: "1", checked: true,
                                         label: "Specimen?")
    end

    assert_html(form,
                "input[type='checkbox'][name='member[specimen]']" \
                "[value='1'][checked]")
  end
end
