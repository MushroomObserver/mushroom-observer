# frozen_string_literal: true

require "test_helper"

class FormCheckboxCollapseTest < ComponentTestCase
  # CheckboxCollapse calls @form.checkbox_field, which calls @form.render.
  # Phlex's render requires @_state to be set (only happens during rendering).
  # Wrap the component inside a TestForm so the form is mid-render when
  # CheckboxCollapse calls its field helpers -- same pattern as
  # test/components/application_form_test.rb.
  class TestForm < Components::ApplicationForm
    attr_accessor :render_block

    def view_template
      instance_eval(&render_block) if render_block
    end
  end

  def setup
    super
    @obs = observations(:minimal_unknown_obs)
  end

  def test_collapse_trigger_on_label_when_closed
    html = render_collapse(expanded: false)

    assert_html(html,
                "label[data-toggle='collapse']" \
                "[data-target='#specimen_fields']" \
                "[aria-controls='specimen_fields']" \
                "[aria-expanded='false']")
  end

  def test_collapse_trigger_on_label_when_expanded
    html = render_collapse(expanded: true)

    assert_html(html,
                "label[data-target='#specimen_fields']" \
                "[aria-expanded='true']")
  end

  def test_trigger_not_on_input
    html = render_collapse(expanded: false)

    assert_no_html(html, "input[data-toggle='collapse']")
  end

  def test_attributes_forwarded_to_checkbox_field
    html = render_collapse(
      attributes: { wrap_class: "mt-0", help: "Some help text" }
    )

    assert_html(html, ".mt-0 input[type='checkbox']")
    assert_html(html, "body", text: "Some help text")
  end

  def test_input_data_in_attributes_goes_to_input_not_label
    html = render_collapse(
      attributes: { data: { "form-exif-target": "collapseCheck" } }
    )

    assert_html(html, "input[data-form-exif-target='collapseCheck']")
    assert_no_html(html, "label[data-form-exif-target='collapseCheck']")
  end

  def test_extra_label_data_merged_with_collapse_trigger
    html = render_collapse(
      attributes: { label_data: { extra: "val" } }
    )

    assert_html(html,
                "label[data-toggle='collapse']" \
                "[data-extra='val']")
  end

  private

  def render_collapse(expanded: false, attributes: {})
    form = TestForm.new(@obs, action: "/observations")
    the_form = form
    form.render_block = proc do
      render(Components::Form::CheckboxCollapse.new(
               form: the_form,
               field: :specimen,
               target_id: "specimen_fields",
               label: "Specimen",
               expanded: expanded,
               attributes: attributes
             ))
    end
    render(form)
  end
end
