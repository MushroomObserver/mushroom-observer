# frozen_string_literal: true

require "test_helper"

# Phlex `ApplicationForm` helper-parity tests.
#
# Pins behaviors where the Phlex helpers were historically diverging
# from their ERB-helper counterparts (or from Rails defaults). Each
# block here corresponds to a fix landed in this PR and exists to
# prevent regression. Pairs with the ERB-side coverage in
# `test/helpers/forms_helper_test.rb`.
class ApplicationFormHelperParityTest < ComponentTestCase
  # --- HiddenField: `autocomplete="off"` matches Rails -------------------

  def test_hidden_field_defaults_autocomplete_off
    html = render(HiddenFieldDefaultsForm.new(Comment.new, action: "/t"))

    # Same default that Rails `hidden_field_tag` emits — browsers
    # otherwise repopulate hidden fields on back-button.
    assert_html(html, "input[type='hidden'][name='comment[summary]']" \
                      "[autocomplete='off']")
  end

  def test_hidden_field_allows_autocomplete_override
    html = render(HiddenFieldOverrideForm.new(Comment.new, action: "/t"))

    # Explicit `autocomplete:` wins over the default.
    assert_html(html, "input[type='hidden'][name='comment[summary]']" \
                      "[autocomplete='on']")
  end

  # --- DateField: `inline:` propagates to outer + inner wraps ------------

  def test_date_field_inline_adds_form_inline_to_outer_wrap
    html = render(DateFieldInlineForm.new(Comment.new, action: "/t"))

    # Outer form-group must carry `form-inline` so the label sits next
    # to the day/month/year inputs instead of breaking onto its own line.
    assert_html(html, "div.form-group.form-inline")
    # And the inner date-selects div gets `d-inline-block` to keep the
    # selects on the same line as the label.
    assert_html(html, "div.date-selects.d-inline-block")
  end

  # --- CheckboxField: hidden sidecar carries `autocomplete="off"` --------

  def test_checkbox_field_hidden_sidecar_has_autocomplete_off
    html = render(CheckboxFieldForm.new(Comment.new, action: "/t"))

    # Matches Rails `form.check_box`: the unchecked-value hidden input
    # gets `autocomplete="off"` so browsers don't restore "0" on
    # back-button and silently clobber a checked box.
    assert_html(html, "input[type='hidden'][name='comment[ok]']" \
                      "[value='0'][autocomplete='off']")
    assert_html(html, "input[type='checkbox'][name='comment[ok]']" \
                      "[value='1']")
  end

  # --- SelectField: `width: :auto` adds `w-auto` ------------------------

  def test_select_field_width_auto_adds_w_auto_class
    html = render(SelectFieldWidthAutoForm.new(Comment.new, action: "/t"))

    # `w-auto` shrinks the select to its content width instead of
    # filling the form-group. Matches ERB `select_with_label(width:
    # :auto)`.
    assert_html(html, "select.form-control.w-auto[name='comment[summary]']")
  end

  def test_select_field_without_width_kwarg_omits_w_auto
    html = render(SelectFieldNoWidthForm.new(Comment.new, action: "/t"))

    sel = Nokogiri::HTML5.fragment(html).at_css("select")
    classes = sel["class"].split
    assert_includes(classes, "form-control")
    assert_not_includes(classes, "w-auto",
                        "w-auto should only be set when width: :auto")
  end

  # --- AutocompleterField: no outer `id` unless caller asks for one ------

  def test_autocompleter_field_omits_outer_id_by_default
    html = render(AutocompleterNoIdForm.new(Comment.new, action: "/t"))

    wrap = Nokogiri::HTML5.fragment(html).at_css("div.autocompleter")
    assert_nil(wrap["id"],
               "outer .autocompleter must not carry an auto-derived id " \
               "when caller didn't pass controller_id:")
  end

  def test_autocompleter_field_emits_outer_id_when_requested
    html = render(AutocompleterCustomIdForm.new(Comment.new, action: "/t"))

    assert_html(html, "div.autocompleter#my_autocompleter_id")
  end

  # --- RadioField: `:append` slot renders after the whole group --------

  def test_radio_field_append_slot_renders_after_last_option
    html = render(RadioFieldAppendForm.new(Comment.new, action: "/t"))

    # All three radio options must appear, followed by the appended
    # content — Phlex `RadioField` is per-group, so `append_slot`
    # lands once after the final `<div class="radio">` wrap.
    radios = html.scan('<div class="radio">')
    assert_equal(3, radios.size, "expected 3 radio option wraps")

    # The append marker must come *after* the last radio's closing
    # </div>, not interleaved with options.
    last_radio_end = html.rindex("</div>", html.index("after-radios"))
    assert(last_radio_end,
           "append content should be emitted after the radio group")
    assert_html(html, "div.after-radios", text: "after the group")
  end

  # --- DateField: `:between` slot renders inline with the label --------

  def test_date_field_between_renders_inline_with_label
    html = render(DateFieldBetweenForm.new(Comment.new, action: "/t"))

    # `between:` should appear inside the label row, not in a separate
    # row or as a sibling of the date selects. FieldLabelRow handles
    # this for DateField via `wrapper_options[:between]`.
    assert_includes(html, "(picker note)")

    # The between content must come BEFORE the date-selects div —
    # confirming it's part of the label row, not appended after.
    between_pos = html.index("(picker note)")
    selects_pos = html.index("date-selects")
    assert(between_pos && selects_pos,
           "both between content and date-selects should be present")
    assert(between_pos < selects_pos,
           "between content must render in the label row " \
           "(before the date-selects)")
  end

  # --- AutocompleterField: no d-flex when label_end is empty -------------

  def test_autocompleter_field_no_d_flex_when_no_create_text
    html = render(AutocompleterNoIdForm.new(Comment.new, action: "/t"))

    # With no `create_text:`, AutocompleterField must not register an
    # empty `label_end` slot — otherwise FieldLabelRow forces the
    # d-flex layout for nothing.
    assert_no_match(/d-flex justify-content-between/, html,
                    "label row must not use d-flex when label_end is empty")
    # The hasIdIndicator (label_after content) still renders inline
    # with the label.
    assert_html(html, "span.has-id-indicator")
  end

  def test_autocompleter_field_uses_d_flex_when_create_text_set
    html = render(AutocompleterCreateForm.new(Comment.new, action: "/t"))

    # `create_text:` populates the label_end slot, so the d-flex
    # wrap is justified: label area left, create button right.
    assert_html(html, "div.d-flex.justify-content-between")
  end

  # --- String field_name: raw `name=` (no model binding) -----------------
  #
  # Each `*_field` helper accepts the same Symbol/String pair as
  # `hidden_field`: Symbol → bound to the form's model; String → raw
  # HTML `name` attribute, value carried via the `value:` option.
  # Lets non-bound fields (operation state, nested namespaces) go
  # through the same helpers as model attributes.

  def test_text_field_accepts_string_name
    html = render(TextFieldStringNameForm.new(Comment.new, action: "/t"))

    assert_html(html, "input[type='text'][name='member[lat]'][value='39.2']")
  end

  def test_textarea_field_accepts_string_name
    html = render(
      TextareaFieldStringNameForm.new(Comment.new, action: "/t")
    )

    assert_html(html, "textarea[name='member[notes][Cap]']", text: "soft")
  end

  def test_checkbox_field_accepts_string_name
    html = render(
      CheckboxFieldStringNameForm.new(Comment.new, action: "/t")
    )

    assert_html(html,
                "input[type='checkbox'][name='member[specimen]']" \
                "[value='1'][checked]")
  end

  def test_select_field_accepts_string_name
    html = render(
      SelectFieldStringNameForm.new(Comment.new, action: "/t")
    )

    assert_html(html, "select[name='member[value]']")
    assert_html(html, "select[name='member[value]'] option[value='2']",
                text: "Two")
  end

  def test_autocompleter_field_accepts_string_name_textarea
    html = render(
      AutocompleterFieldStringNameForm.new(Comment.new, action: "/t")
    )

    assert_html(html, "textarea[name='list[members]']", text: "alpha")
    assert_html(html,
                "div.autocompleter[data-controller='autocompleter--name']")
  end

  # --- Symbol + explicit value: overrides model attribute ---------------
  #
  # Matches Rails ERB's `f.text_field :foo, value: "override"` —
  # explicit `value:` wins over the model. Routes the field through
  # `FieldProxy` with the Superform-namespaced name so the override
  # works for radio/select/checkbox-collection mode too (those drive
  # selection from the field's value, not from a per-input attribute).

  def test_text_field_symbol_with_value_overrides_model
    # Comment has `summary` attribute. Model gives "from-model";
    # caller passes `value: "from-caller"` — explicit wins.
    html = render(TextFieldSymbolOverrideForm.new(
                    Comment.new(summary: "from-model"), action: "/t"
                  ))

    assert_html(html, "input[name='comment[summary]'][value='from-caller']")
  end

  def test_radio_field_symbol_with_value_selects_non_model_attribute
    # Comment has no `target_id` attribute. With Symbol path and
    # explicit `value: 2`, the option whose value is "2" pre-selects.
    html = render(RadioFieldSymbolOverrideForm.new(Comment.new, action: "/t"))

    assert_html(html,
                "input[type='radio'][name='comment[target_id]']" \
                "[value='2'][checked]")
    assert_html(html,
                "input[type='radio'][name='comment[target_id]']" \
                "[value='1']:not([checked])")
  end
end

# --- Test form classes -------------------------------------------------

class HiddenFieldDefaultsForm < Components::ApplicationForm
  def view_template
    super { hidden_field(:summary, value: "x") }
  end
end

class HiddenFieldOverrideForm < Components::ApplicationForm
  def view_template
    super { hidden_field(:summary, value: "x", autocomplete: "on") }
  end
end

class DateFieldInlineForm < Components::ApplicationForm
  def view_template
    super do
      date_field(:created_at, inline: true, label: "When:")
    end
  end
end

class CheckboxFieldForm < Components::ApplicationForm
  def view_template
    super { checkbox_field(:ok, label: "OK?") }
  end
end

class SelectFieldWidthAutoForm < Components::ApplicationForm
  def view_template
    super do
      select_field(:summary, [%w[a A], %w[b B]], width: :auto, label: "S:")
    end
  end
end

class SelectFieldNoWidthForm < Components::ApplicationForm
  def view_template
    super do
      select_field(:summary, [%w[a A], %w[b B]], label: "S:")
    end
  end
end

class RadioFieldAppendForm < Components::ApplicationForm
  def view_template
    super do
      radio_field(:summary, [1, "One"], [2, "Two"], [3, "Three"]) do |f|
        f.with_append { div(class: "after-radios") { "after the group" } }
      end
    end
  end
end

class DateFieldBetweenForm < Components::ApplicationForm
  def view_template
    super do
      date_field(:created_at, label: "When:", between: "(picker note)")
    end
  end
end

class AutocompleterNoIdForm < Components::ApplicationForm
  def view_template
    super do
      render(field(:summary).autocompleter(
               type: :name,
               wrapper_options: { label: "Name" }
             ))
    end
  end
end

class AutocompleterCustomIdForm < Components::ApplicationForm
  def view_template
    super do
      render(field(:summary).autocompleter(
               type: :name,
               controller_id: "my_autocompleter_id",
               wrapper_options: { label: "Name" }
             ))
    end
  end
end

class AutocompleterCreateForm < Components::ApplicationForm
  def view_template
    super do
      render(field(:summary).autocompleter(
               type: :name,
               create_text: "Create new",
               wrapper_options: { label: "Name" }
             ))
    end
  end
end

# String-`field_name` form fixtures — each helper accepts a raw HTML
# `name=` (e.g. nested non-model namespaces like `member[lat]`,
# `list[members]`) just like `hidden_field` already does.

class TextFieldStringNameForm < Components::ApplicationForm
  def view_template
    super { text_field("member[lat]", value: "39.2", label: "Lat:") }
  end
end

class TextareaFieldStringNameForm < Components::ApplicationForm
  def view_template
    super { textarea_field("member[notes][Cap]", value: "soft", rows: 1) }
  end
end

class CheckboxFieldStringNameForm < Components::ApplicationForm
  def view_template
    super do
      checkbox_field("member[specimen]", value: "1", checked: true,
                                         label: "Specimen?")
    end
  end
end

class SelectFieldStringNameForm < Components::ApplicationForm
  def view_template
    super do
      select_field("member[value]",
                   [["One", 1], ["Two", 2], ["Three", 3]],
                   label: "Confidence:")
    end
  end
end

class AutocompleterFieldStringNameForm < Components::ApplicationForm
  def view_template
    super do
      autocompleter_field("list[members]", type: :name, textarea: true,
                                           value: "alpha",
                                           label: "Names:")
    end
  end
end

# Symbol + explicit value: form fixtures — caller-supplied `value:`
# overrides whatever the form's model attribute would produce.

class TextFieldSymbolOverrideForm < Components::ApplicationForm
  def view_template
    super { text_field(:summary, value: "from-caller", label: "Summary:") }
  end
end

class RadioFieldSymbolOverrideForm < Components::ApplicationForm
  def view_template
    super do
      radio_field(:target_id, [1, "One"], [2, "Two"], value: 2,
                                                      label: "Target:")
    end
  end
end
