# frozen_string_literal: true

require "test_helper"

# TEMPORARY: parity test comparing the soon-to-be-deleted ERB
# field-slip form (`_form_old.html.erb` + matrix sub-partials +
# `shared/_notes_fields_old.html.erb`) against the new
# `Components::FieldSlipForm` Phlex equivalent.
#
# Walks each form mode and uses `assert_html_element_equivalent`
# (selector-scoped, attribute-order-agnostic) to verify the Phlex
# render isn't dropping classes, attributes, or nesting that the
# ERB had. Delete this file (and the `*_old.html.erb` snapshots)
# once the Phlex form ships.
#
# === TODO before this test is useful ===
#
# `assert_html_element_equivalent` (added in #4246) is currently
# strict about full-subtree equivalence, which falsely flags MO's
# Phlex `TextField` against MO's ERB `text_field_with_label`:
#
#   - The Phlex `FieldLabelRow` module short-circuits to a plain
#     `<label class="mr-3">…</label>` when `simple_label?` is true
#     (no `help:`, `between:`, or `label_end` slot). This is
#     intentional leanness.
#   - The ERB helper *always* wraps the label in
#     `<div class="d-flex justify-content-between">
#        <div><label/></div>
#        <div></div>           <!-- empty when no help icon -->
#      </div>`
#     even when the right-hand `<div>` is empty.
#
# So when a Phlex form field has no help/between/label_end, the
# ERB version emits an empty `<div></div>` of dead scaffolding that
# the Phlex version (correctly) omits. The parity test should
# tolerate that *specific* empty-label-row shape, but NOT tolerate
# missing markup when the label row carries real UI (help icon,
# autocompleter feedback icon, etc.) — those affordances must
# round-trip exactly.
#
# Suggested fix (next session): teach this test (or extend
# `assert_html_element_equivalent` with an opt-in) to normalize the
# "empty label-row wrapper" before comparison, e.g. collapse a
# `<div class="d-flex justify-content-between">
#    <div><label.../></div>
#    <div></div>
#  </div>`
# into a bare `<label.../>` on whichever side has the wrapper. Then
# any non-empty `<div>` content inside the row will fail the
# comparison (which is exactly what we want).
class FieldSlipFormParityTest < ComponentTestCase
  def setup
    super
    # ApplicationController appends `app/views/controllers` to the
    # view paths; the test controller (ActionView::TestCase::TestController)
    # does not by default, so the ERB partial isn't found without this.
    @controller.append_view_path(Rails.root.join("app/views/controllers"))
    @user = users(:rolf)
    User.current = @user
    @field_slip = field_slips(:field_slip_one)
    @recent = [
      observations(:minimal_unknown_obs),
      observations(:coprinus_comatus_obs)
    ]
  end

  # --- "New" action with recent observations to pick from ---

  # The form tag's `id` differs by design (ERB uses Rails' default
  # `new_field_slip` from `form_with(model:)`; Phlex uses
  # `field_slip_form` from class name). Compare inside the form so
  # the id mismatch doesn't drown out the meaningful diffs.

  def test_new_with_recent_obs_left_column
    erb = render_erb(action: "new")
    phlex = render_phlex(action: "new")
    assert_html_element_equivalent(erb, phlex,
                                   selector: "div.col-md-6",
                                   label: "new-with-recent / left col")
  end

  # --- Sanity: dump both HTMLs to /tmp for visual inspection when needed ---

  private

  def render_erb(action:)
    stub_action(action)
    @controller.instance_variable_set(:@recent_observations, @recent)
    @controller.instance_variable_set(:@field_slip, @field_slip)
    @controller.instance_variable_set(:@user, @user)
    view_context.render(partial: "field_slips/form_old",
                        locals: { field_slip: @field_slip,
                                  species_list: nil })
  end

  def render_phlex(action:)
    render(Components::FieldSlipForm.new(@field_slip,
                                         action: action,
                                         recent_observations: @recent,
                                         user: @user))
  end

  # Component tests don't actually flow through an action; the ERB
  # partial reads `controller.action_name`, so stub it on the test
  # controller.
  def stub_action(name)
    @controller.define_singleton_method(:action_name) { name }
  end
end
