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
# Mode selection differs between ERB and Phlex:
#   - ERB reads `controller.action_name` (stubbed below).
#   - Phlex derives from `model.new_record?` (MO convention; cf.
#     `description_form.rb`). So "new" mode is tested with an
#     unsaved `FieldSlip.new` carrying the fixture's attributes,
#     and "edit" mode with the saved fixture itself.
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
    erb = render_erb(action: "new", field_slip: new_field_slip_like_fixture)
    phlex = render_phlex(field_slip: new_field_slip_like_fixture)
    assert_html_element_equivalent(erb, phlex,
                                   selector: "div.col-md-6",
                                   label: "new-with-recent / left col")
  end

  # --- Sanity: dump both HTMLs to /tmp for visual inspection when needed ---

  private

  # Unsaved record carrying the same attribute values as
  # `field_slips(:field_slip_one)` — for testing the "new" mode parity.
  # Both ERB (via stubbed `controller.action_name`) and Phlex (via
  # `model.new_record?`) will render the new layout.
  def new_field_slip_like_fixture
    saved = field_slips(:field_slip_one)
    FieldSlip.new(saved.attributes.except("id", "created_at", "updated_at"))
  end

  def render_erb(action:, field_slip:)
    stub_action(action)
    @controller.instance_variable_set(:@recent_observations, @recent)
    @controller.instance_variable_set(:@field_slip, field_slip)
    @controller.instance_variable_set(:@user, @user)
    view_context.render(partial: "field_slips/form_old",
                        locals: { field_slip: field_slip,
                                  species_list: nil })
  end

  def render_phlex(field_slip:)
    render(Components::FieldSlipForm.new(field_slip,
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
