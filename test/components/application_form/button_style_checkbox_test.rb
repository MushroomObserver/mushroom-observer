# frozen_string_literal: true

require("test_helper")

# Tests for Components::ApplicationForm::ButtonStyleCheckbox — the
# button-styled checkbox parallel of ButtonStyleRadio. Used by the
# activity-log filter UI and other multi-select filter contexts.
# Unlike CheckboxField, this component is standalone (no
# Field/FieldProxy) and has NO `.checkbox` div wrap.
class ButtonStyleCheckboxTest < ComponentTestCase
  def test_renders_label_wrapping_checkbox_input
    html = render(klass.new(
                    name: "q[type][]", value: "observation",
                    id: "type_observation"
                  )) { "Observations" }

    # <label for="type_observation">
    #   <input type="checkbox" ...>Observations
    # </label>
    assert_html(html, "label[for='type_observation'] > input[type='checkbox']" \
                      "[name='q[type][]'][value='observation']" \
                      "[id='type_observation']")
    assert_includes(html, "Observations")
    # No `.checkbox` div wrap — intentional (this is the filter-button
    # variant, not the vertical-checkbox-list variant).
    assert_no_html(html, ".checkbox")
  end

  def test_checked_true_sets_input_attr
    html = render(klass.new(
                    name: "n[]", value: "1", id: "x", checked: true
                  ))

    assert_html(html, "input[type='checkbox'][checked]")
  end

  def test_checked_default_false_omits_attr
    html = render(klass.new(name: "n[]", value: "1", id: "x"))

    assert_html(html, "input[type='checkbox']:not([checked])")
  end

  def test_variant_and_size_applied_to_label
    html = render(klass.new(
                    name: "n[]", value: "1", id: "x",
                    variant: :outline, size: :sm,
                    label: { class: "filter-checkbox",
                             data: { action: "click->filter#toggle" } }
                  ))

    assert_html(html, "label[for='x']")
    assert_html(html, "label[data-action='click->filter#toggle']")
  end

  def test_input_attrs_passed_through_via_splat
    html = render(klass.new(
                    name: "n[]", value: "1", id: "x",
                    class: "form-control",
                    data: { filter_id: "1" }
                  ))

    assert_html(html, "input[type='checkbox'].form-control" \
                      "[data-filter-id='1']")
  end

  def test_renders_without_block_content
    html = render(klass.new(name: "n[]", value: "1", id: "x"))

    # Label exists, contains the input, no extra content.
    assert_html(html, "label[for='x'] > input[type='checkbox']")
  end

  # Multiple instances with the same name[] form a multi-select group
  # — that's the whole reason this component exists separately from
  # ButtonStyleRadio. Verify the name-array shape is preserved.
  def test_multiple_instances_share_name_array_shape
    html_a = render(klass.new(name: "q[type][]", value: "a", id: "ta"))
    html_b = render(klass.new(name: "q[type][]", value: "b", id: "tb"))

    assert_html(html_a, "input[name='q[type][]'][value='a']")
    assert_html(html_b, "input[name='q[type][]'][value='b']")
  end

  private

  def klass
    Components::ApplicationForm::ButtonStyleCheckbox
  end
end
