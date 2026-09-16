# frozen_string_literal: true

require "test_helper"

# Tests for the `textarea_field` ApplicationForm helper.
class TextareaFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Textarea field tests
  def test_textarea_field_renders_with_basic_options
    form = render_form do
      textarea_field(:notes, label: "Notes")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Notes")
    assert_includes(form, "form-control")
    assert_includes(form, "<textarea")
  end

  def test_textarea_field_with_monospace
    form = render_form do
      textarea_field(:notes, label: "Notes", monospace: true)
    end

    assert_includes(form, "text-monospace")
  end

  # Regression: TextareaField applies `text-monospace` when instantiated
  # directly with `wrapper_options[:monospace]` — not just via the helper.
  # Matches ERB `text_area_with_label`'s `:monospace` semantics so direct
  # component callers (e.g. FieldProxy-backed textareas) get parity.
  def test_textarea_field_monospace_at_component_level
    form = Components::ApplicationForm.new(@collection_number,
                                           action: "/test_form_path")
    field = form.field(:notes)
    component = Components::ApplicationForm::TextareaField.new(
      field, wrapper_options: { label: "Notes", monospace: true }
    )

    html = render(component)
    assert_html(html, "textarea.form-control.text-monospace")
  end

  def test_textarea_field_with_rows
    form = render_form do
      textarea_field(:notes, label: "Notes", rows: 10)
    end

    assert_includes(form, 'rows="10"')
  end

  # The `prepend` slot renders inside the form-group, between the label
  # row and the textarea (symmetric with `append`, which renders after).
  def test_textarea_field_with_prepend
    form = render_form do
      textarea_field(:notes, label: "Notes") do |f|
        f.with_prepend { select(class: "value-source") { option { "x" } } }
      end
    end

    assert_html(form, ".form-group select.value-source")
    group = Nokogiri::HTML5.fragment(form).at_css(".form-group")
    order = group.css("label, select, textarea").map(&:name)
    assert_equal(%w[label select textarea], order)
  end

  def test_textarea_field_accepts_string_name
    form = render_comment_form do
      textarea_field("member[notes][Cap]", value: "soft", rows: 1)
    end

    assert_html(form, "textarea[name='member[notes][Cap]']", text: "soft")
  end
end
