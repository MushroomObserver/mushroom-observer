# frozen_string_literal: true

require("test_helper")

# Tests for Components::FieldSlipForm — the Phlex conversion of the
# field-slip form (replaces app/views/controllers/field_slips/_form.erb
# plus its matrix sub-partials).
#
# Focus areas:
# 1. Render-mode branching (code-only vs main form)
# 2. New-record vs existing-record submit buttons
# 3. Errors-present rendering
# 4. Project-select visibility
# 5. Observation matrix FieldProxy param wiring — the most regression-
#    prone path (flat `observation_ids[]` + namespaced
#    `field_slip[primary_observation_id]`), and the part with no
#    assertions elsewhere in the codebase per coverage audit
class FieldSlipFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  # ---------- Code-only mode ----------

  def test_code_only_form_when_model_has_no_code
    html = render_form(FieldSlip.new)

    # GET form to /field_slips/new — the "enter code" entry point.
    assert_html(html, "form[action='/field_slips/new'][method='get']")
    assert_html(html, "input[type='text'][name='field_slip[code]']" \
                      "[id='field_slip_code']")
    assert_html(html, "input[type='submit']")
    # Main-form fields shouldn't appear in code-only mode.
    assert_no_html(html, "input[name='field_slip[other_codes]']")
    assert_no_html(html, "input[name='field_slip[inat]']")
  end

  # ---------- Main form (new record) ----------

  def test_new_record_main_form_renders_all_attribute_fields
    html = render_form(FieldSlip.new(code: "TEST-001"))

    # POST to /field_slips (Superform picks POST for new records).
    assert_html(html, "form[action='/field_slips'][method='post']")
    # All the left-column attribute fields.
    assert_html(html, "input[type='text'][name='field_slip[code]']")
    assert_html(html, "input[type='text'][name='field_slip[other_codes]']")
    assert_html(html, "input[type='checkbox'][name='field_slip[inat]']")
    # Autocompleter inputs for collector / location / name / id_by.
    assert_html(html, "input[name='field_slip[collector]']")
    assert_html(html, "input[name='field_slip[location]']")
    assert_html(html, "input[name='field_slip[field_slip_name]']")
    assert_html(html, "input[name='field_slip[field_slip_id_by]']")
  end

  def test_new_record_renders_new_record_submit_buttons
    html = render_form(FieldSlip.new(code: "TEST-002"))

    # Quick-create + add-images submits (both new-record only).
    assert_includes(html, :field_slip_quick_create_obs.t)
    assert_includes(html, :field_slip_add_images.t)
    # Edit-only buttons should NOT appear.
    assert_not_includes(html, :SAVE_EDITS.t)
  end

  def test_species_list_hidden_field_always_emitted
    # The param key must exist on submit; empty value is fine.
    html = render_form(FieldSlip.new(code: "TEST-003"))

    assert_html(html, "input[type='hidden'][name='species_list']")
  end

  def test_species_list_hidden_field_carries_passed_value
    html = render_form(FieldSlip.new(code: "TEST-004"),
                       species_list: "42")

    assert_html(html, "input[type='hidden'][name='species_list'][value='42']")
  end

  # ---------- Existing record (edit) ----------

  def test_existing_record_renders_edit_submit_buttons
    fs = field_slips(:field_slip_one)
    html = render_form(fs)

    # Edit-mode submits.
    assert_includes(html, :SAVE_EDITS.t)
    assert_includes(html, :field_slip_create_obs.t)
    # New-record-only buttons should NOT appear.
    assert_not_includes(html, :field_slip_quick_create_obs.t)
  end

  def test_existing_record_uses_patch_method
    fs = field_slips(:field_slip_one)
    html = render_form(fs)

    # Superform: persisted record → PATCH via _method hidden field.
    assert_html(html, "form[method='post']")
    assert_html(html, "input[type='hidden'][name='_method'][value='patch']")
    # Action targets the specific record.
    assert_html(html, "form[action='/field_slips/#{fs.id}']")
  end

  # ---------- Errors branch ----------

  def test_renders_alert_when_model_has_errors
    fs = FieldSlip.new(code: "TEST-005")
    fs.errors.add(:code, "is taken")
    fs.errors.add(:base, "something else broke")
    html = render_form(fs)

    # Renders Components::Alert with the error list.
    assert_html(html, ".alert.alert-danger")
    assert_includes(html, "is taken")
    assert_includes(html, "something else broke")
  end

  def test_no_alert_when_model_has_no_errors
    html = render_form(FieldSlip.new(code: "TEST-006"))

    assert_no_html(html, ".alert.alert-danger")
  end

  # ---------- Project select ----------

  def test_renders_project_select_when_model_has_projects
    fs = field_slips(:field_slip_one) # belongs to eol_project
    html = render_form(fs)

    # Select with one or more <option> rows from model.projects.
    assert_html(html, "select[name='field_slip[project_id]']")
  end

  def test_project_select_includes_nil_sentinel_option
    fs = field_slips(:field_slip_one)
    html = render_form(fs)

    # FieldSlip#projects always unshifts a `[nil_label, nil]` sentinel,
    # so the select always includes the "no project" option even when
    # a real project is selected. This guards against a refactor that
    # would drop the sentinel and break the "unset project" UX.
    assert_html(
      html,
      "select[name='field_slip[project_id]'] > option[value='']"
    )
  end

  # ---------- Observation matrix (FieldProxy param wiring) ----------
  #
  # CRITICAL: these tests pin the param-name contract between the form
  # and field_slips_controller. A change to the FieldProxy namespace
  # would silently break form submission — this is the only test that
  # would catch it. (Coverage audit: no other tests anywhere assert on
  # `observation_ids[]` or `field_slip[primary_observation_id]`.)

  def test_new_action_matrix_uses_flat_observation_ids
    recent = [observations(:minimal_unknown_obs),
              observations(:coprinus_comatus_obs)]
    html = render_form(FieldSlip.new(code: "TEST-008"),
                       recent_observations: recent)

    # Flat `observation_ids[]` — NOT namespaced under `field_slip[]`,
    # because FieldSlip has no `observation_ids=` accessor (join is via
    # the occurrence). The controller reads `params[:observation_ids]`
    # directly.
    recent.each do |obs|
      assert_html(html, "input[type='checkbox']" \
                        "[name='observation_ids[]'][value='#{obs.id}']")
    end
  end

  def test_new_action_matrix_primary_radio_uses_namespaced_field_slip
    recent = [observations(:minimal_unknown_obs)]
    html = render_form(FieldSlip.new(code: "TEST-009"),
                       recent_observations: recent)

    # Primary-observation radio IS namespaced under `field_slip[]` —
    # different convention than the `observation_ids[]` checkbox.
    assert_html(
      html,
      "input[type='radio']" \
      "[name='field_slip[primary_observation_id]']" \
      "[value='#{recent.first.id}']"
    )
  end

  def test_new_action_matrix_starts_with_no_checked_boxes
    recent = [observations(:minimal_unknown_obs),
              observations(:coprinus_comatus_obs)]
    html = render_form(FieldSlip.new(code: "TEST-010"),
                       recent_observations: recent)

    # All checkboxes unchecked in new-action context (no current obs).
    recent.each do |obs|
      assert_html(html, "input[name='observation_ids[]']" \
                        "[value='#{obs.id}']:not([checked])")
    end
  end

  def test_no_observation_matrix_on_new_form_without_recent_obs
    html = render_form(FieldSlip.new(code: "TEST-011"))

    # No matrix at all if there are no recent observations.
    assert_no_html(html, "input[name='observation_ids[]']")
    assert_no_html(html, "input[name='field_slip[primary_observation_id]']")
  end

  # ---------- form_attributes id fallback ----------

  def test_form_gets_field_slip_form_id_by_default
    html = render_form(FieldSlip.new(code: "TEST-012"))

    assert_html(html, "form#field_slip_form")
  end

  private

  def render_form(model, **)
    render(Components::FieldSlipForm.new(
             model, user: @user, **
           ))
  end
end
