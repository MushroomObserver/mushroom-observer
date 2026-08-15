# frozen_string_literal: true

require "test_helper"

# Tests for the `select_field` ApplicationForm helper.
class SelectFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Select field tests
  def test_select_field_renders_with_basic_options
    options = [["Option 1", "1"], ["Option 2", "2"], ["Option 3", "3"]]
    form = render_form do
      select_field(:number, options, label: "Choose")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Choose")
    assert_includes(form, "form-control")
    assert_includes(form, "<select")
    assert_includes(form, "Option 1")
    assert_includes(form, "Option 2")
    assert_includes(form, "Option 3")
  end

  # Regression: a `[Label, nil]` pair (Rails-shape, value is nil) must
  # render `<option value="">Label`, not `<option>Label` (which would
  # submit "Label" as the value). Phlex's HTML DSL omits nil-valued
  # attributes by default, so SelectField coerces nil values to "" to
  # match Rails' select-helper behavior.
  def test_select_field_nil_value_renders_empty_value_attribute
    options = [["(No Project)", nil], ["EOL Project", "778455076"]]
    form = render_form do
      select_field(:number, options, label: "Project")
    end

    assert_html(form, "option[value='']", text: "(No Project)")
    assert_html(form, "option[value='778455076']", text: "EOL Project")
  end

  # Test select with custom options block - renders component directly
  def test_select_field_with_custom_options_block
    # Create a field for testing
    form = Components::ApplicationForm.new(@collection_number,
                                           action: "/test_form_path")
    select_field = form.field(:number)
    select_component = select_field.select([])

    # Render with custom options block using view_context helpers
    html = render(select_component) do
      view_context.tag.option("Option A", value: "a") +
        view_context.tag.option("Option B", value: "b")
    end

    assert_includes(html, "<select")
    assert_includes(html, "Option A")
    assert_includes(html, "Option B")
    assert_includes(html, 'value="a"')
    assert_includes(html, 'value="b"')
  end

  # Test select field with inferred label (no label option, uses humanize)
  # Covers SelectField line 62: field.key.to_s.humanize
  def test_select_field_with_inferred_label
    options = [["Opt 1", "1"], ["Opt 2", "2"]]
    form = render_form do
      select_field(:collection_name, options)
    end

    # Field name :collection_name should be humanized to "Collection name"
    assert_includes(form, "Collection name")
    assert_includes(form, "<select")
  end

  # Test select with label: true (explicit non-string, non-false label)
  # Also covers SelectField line 62
  def test_select_field_with_label_true
    options = [["Opt A", "a"], ["Opt B", "b"]]
    form = render_form do
      select_field(:number, options, label: true)
    end

    # Should use humanized field name as label
    assert_includes(form, "Number")
    assert_includes(form, "<select")
  end

  # Regression: select_field's width: :auto adds w-auto, shrinking the
  # select to its content width instead of filling the form-group.
  def test_select_field_width_auto_adds_w_auto_class
    form = render_comment_form do
      select_field(:summary, [%w[a A], %w[b B]], width: :auto, label: "S:")
    end

    assert_html(form, "select.form-control.w-auto[name='comment[summary]']")
  end

  def test_select_field_without_width_kwarg_omits_w_auto
    form = render_comment_form do
      select_field(:summary, [%w[a A], %w[b B]], label: "S:")
    end

    sel = Nokogiri::HTML5.fragment(form).at_css("select")
    classes = sel["class"].split
    assert_includes(classes, "form-control")
    assert_not_includes(classes, "w-auto",
                        "w-auto should only be set when width: :auto")
  end

  def test_select_field_accepts_string_name
    form = render_comment_form do
      select_field("member[value]",
                   [["One", 1], ["Two", 2], ["Three", 3]],
                   label: "Confidence:")
    end

    assert_html(form, "select[name='member[value]']")
    assert_html(form, "select[name='member[value]'] option[value='2']",
                text: "Two")
  end
end
