# frozen_string_literal: true

require "test_helper"

# Tests for the `hidden_field` ApplicationForm helper.
class HiddenFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Hidden field tests
  def test_hidden_field_renders_without_wrapper
    form = render_form do
      hidden_field(:secret, value: "hidden_value")
    end

    assert_includes(form, 'type="hidden"')
    assert_includes(form, 'value="hidden_value"')
    assert_not_includes(form, "form-group")
  end

  # Regression: hidden inputs used to emit `class="form-control"` —
  # harmless visually (hidden inputs don't render) but wrong markup,
  # and inconsistent between Symbol and String paths (Symbol detoured
  # through TextField; String through HiddenField). Both paths now
  # route through `HiddenField`, the dedicated hidden-input component.
  # The Symbol path passes Superform's `field(:x)` directly — same
  # `.dom.id`/`.dom.name`/`.value` interface as `FieldProxy`.
  def test_hidden_field_symbol_key_does_not_emit_form_control
    form = render_form do
      hidden_field(:secret, value: "x")
    end
    doc = Nokogiri::HTML(form)
    input = doc.at_css("input[type='hidden'][name*='secret']")
    assert(input, "Hidden input must render")
    assert_not_includes(input["class"] || "", "form-control",
                        "Symbol-keyed hidden_field must not emit form-control")
  end

  def test_hidden_field_string_key_does_not_emit_form_control
    form = render_form do
      hidden_field("approved_where", value: "x")
    end
    doc = Nokogiri::HTML(form)
    input = doc.at_css("input[type='hidden'][name='approved_where']")
    assert(input, "Hidden input must render")
    assert_not_includes(input["class"] || "", "form-control",
                        "String-keyed hidden_field must not emit form-control")
  end

  # Symbol-keyed `hidden_field` keeps Superform's namespaced name
  # (e.g. `<model_name>[<field>]`) — the whole point of going through
  # `field(...)` rather than the raw String path. Locks that in.
  def test_hidden_field_symbol_key_uses_superform_namespace
    form = render_form do
      hidden_field(:secret, value: "x")
    end
    # The render_form helper builds an anonymous form whose model
    # defaults to a Collection Number; the form's namespace is
    # "collection_number". The hidden field should be namespaced
    # under it.
    assert_match(/name="collection_number\[secret\]"/, form,
                 "Symbol-keyed hidden_field must namespace under the model")
  end

  # Most callers in the codebase rely on the Symbol path auto-reading
  # the value from the form's model/FormObject (e.g.
  # `descriptions/form.rb hidden_field(:project_id)` reads
  # `form.model.project_id`). Passing Superform's `field(:x)` directly
  # to HiddenField preserves that — `HiddenField` reads `.value` off
  # the field, and Superform's field knows the model's value.
  def test_hidden_field_symbol_key_auto_reads_value_from_model
    # `@collection_number.name` == "Rolf Singer" per the fixture.
    form = render_form do
      hidden_field(:name) # no explicit value:
    end
    doc = Nokogiri::HTML(form)
    input = doc.at_css("input[type='hidden'][name='collection_number[name]']")
    assert(input, "Hidden input must render")
    assert_equal("Rolf Singer", input["value"],
                 "Symbol-keyed hidden_field with no value: must auto-read " \
                 "from the form's model/FormObject")
  end

  # Caller's explicit `value:` always wins, even when the model has
  # a value for the attribute. (HiddenField's `@attributes.fetch(:value)`
  # uses the override before falling back to `@field.value`.)
  def test_hidden_field_symbol_key_explicit_value_overrides_model
    form = render_form do
      hidden_field(:name, value: "OVERRIDE")
    end
    doc = Nokogiri::HTML(form)
    input = doc.at_css("input[type='hidden'][name='collection_number[name]']")
    assert_equal("OVERRIDE", input["value"],
                 "Explicit value: must override the model's value")
  end

  # Regression: hidden_field defaults autocomplete="off", same as Rails
  # hidden_field_tag -- browsers otherwise repopulate hidden fields on
  # back-button.
  def test_hidden_field_defaults_autocomplete_off
    form = render_comment_form { hidden_field(:summary, value: "x") }

    assert_html(form, "input[type='hidden'][name='comment[summary]']" \
                      "[autocomplete='off']")
  end

  def test_hidden_field_allows_autocomplete_override
    form = render_comment_form do
      hidden_field(:summary, value: "x", autocomplete: "on")
    end

    assert_html(form, "input[type='hidden'][name='comment[summary]']" \
                      "[autocomplete='on']")
  end
end
