# frozen_string_literal: true

require "test_helper"

class FormRadioCollapseTest < ComponentTestCase
  # Same pattern as FormCheckboxCollapseTest: RadioCollapse calls
  # @form.radio_field, which needs the form mid-render.
  class TestForm < Components::ApplicationForm
    attr_accessor :render_block

    def view_template
      instance_eval(&render_block) if render_block
    end
  end

  def setup
    super
    @donation = Donation.new
  end

  def test_change_action_wires_collapse_switch
    html = render_collapse(value: "other")

    assert_html(html,
                "input[type='radio']" \
                "[data-action='change->collapse-switch#switch']")
  end

  def test_caller_data_merges_alongside_collapse_switch_action
    html = render_collapse(
      value: "other",
      attributes: { data: { donate_target: "otherCheck" } }
    )

    assert_html(html,
                "input[type='radio']" \
                "[data-action='change->collapse-switch#switch']" \
                "[data-donate-target='otherCheck']")
  end

  # Caller-supplied data: with an :action key wins the merge -- the
  # same override capability CheckboxCollapse's label_data/toggle/
  # target attrs have (test_checked_can_be_overridden_by_the_caller
  # is the equivalent case there). A caller doing this on purpose is
  # responsible for including the collapse-switch action itself if it
  # still wants that wiring.
  def test_caller_action_in_data_overrides_collapse_switch_action
    html = render_collapse(
      value: "other",
      attributes: { data: { action: "click->other#thing" } }
    )

    assert_html(html,
                "input[type='radio'][data-action='click->other#thing']")
    assert_no_html(html, "input[data-action*='collapse-switch']")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_wrap_class_forwarded
    html = render_collapse(value: "other",
                           attributes: { wrap_class: "mb-3" })

    assert_html(html, ".mb-3 input[type='radio']")
  end

  def test_label_accepts_bare_string
    html = render_collapse(value: "other", label: "Other Amount:")

    assert_html(html, "label", text: "Other Amount:")
  end

  private

  def render_collapse(value:, label: "Other", attributes: {})
    form = TestForm.new(@donation, action: "/support")
    the_form = form
    form.render_block = proc do
      render(Components::Form::RadioCollapse.new(
               form: the_form,
               field: :amount,
               value: value,
               label: label,
               attributes: attributes
             ))
    end
    render(form)
  end
end
