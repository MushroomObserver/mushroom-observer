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
