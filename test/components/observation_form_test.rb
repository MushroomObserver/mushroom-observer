# frozen_string_literal: true

require("test_helper")

class ObservationFormTest < ComponentTestCase
  def test_new_form_posts_to_observations
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(observation: obs, user: user, mode: :create)

    # Should post to /observations (no query params on initial load)
    assert_html(html, "form[action='/observations'][method='post']")
  end

  def test_form_includes_approval_params_when_present
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(
      observation: obs,
      user: user,
      mode: :create,
      given_name: "Agaricus",
      place_name: "California"
    )

    # Form action should include approval query params
    assert_html(html, "form[action*='approved_name=Agaricus']")
    assert_html(html, "form[action*='approved_where=California']")
  end

  def test_place_name_input_has_map_target
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(observation: obs, user: user, mode: :create)

    # The place_name input should have data-map-target="placeInput"
    # to enable the map controller to clear it
    assert_html(html, "input[name='observation[place_name]']" \
                      "[data-map-target='placeInput']")
  end

  def test_file_input_has_accept_attribute
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(observation: obs, user: user, mode: :create)

    # File input should restrict to images to prevent folder selection errors
    assert_html(html, "input[type='file'][accept='image/*']")
  end

  # --- Field Slip Code ---

  def test_new_form_shows_editable_field_slip_code
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(observation: obs, user: user, mode: :create)

    assert_html(html, "input[name='field_code'][type='text']")
    assert_no_html(html, "input[name='field_code'][type='hidden']")
  end

  def test_new_form_locked_field_code_shows_static_display
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(observation: obs, user: user, mode: :create,
                       field_code: "NEMF-1234",
                       field_code_locked: true)

    # Static display + hidden inputs
    assert_includes(html, "NEMF-1234")
    assert_html(html, "input[name='field_code'][type='hidden']" \
                      "[value='NEMF-1234']")
    assert_html(html, "input[name='field_code_locked']" \
                      "[value='1']")
    # No editable text input for field_code
    assert_no_html(html, "input[name='field_code'][type='text']")
  end

  def test_new_form_preserves_user_entered_field_code
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(observation: obs, user: user, mode: :create,
                       field_code: "NEMF-5678",
                       field_code_locked: false)

    # Editable input pre-populated
    assert_html(html, "input[name='field_code'][type='text']" \
                      "[value='NEMF-5678']")
    # No locked display
    assert_no_html(html, "input[name='field_code_locked']")
  end

  def test_edit_form_shows_field_slip_code_from_model
    user = users(:rolf)
    obs = observations(:minimal_unknown_obs)
    fs = field_slips(:field_slip_no_obs)
    obs.update!(occurrence: nil)
    obs.field_slip = fs
    obs.save!

    html = render_form(observation: obs, user: user, mode: :update)

    assert_html(html, "input[name='field_code'][type='text']" \
                      "[value='#{fs.code}']")
  end

  def test_edit_form_shows_empty_field_code_without_slip
    user = users(:rolf)
    obs = observations(:minimal_unknown_obs)
    obs.update!(occurrence: nil)

    html = render_form(observation: obs, user: user, mode: :update)

    assert_html(html, "input[name='field_code'][type='text']")
  end

  # #4136: per-project warning annotation lists the violation kinds
  # that apply to this obs against this project, not the project's
  # date/location *settings* (which are uninformative when the project
  # only has target_names / target_locations).
  def test_constraint_warning_lists_violation_kinds_per_project
    user = users(:rolf)
    proj = projects(:rare_fungi_project)
    proj.project_target_names.destroy_all
    proj.project_target_locations.destroy_all
    proj.update!(start_date: nil, end_date: nil, location: nil)
    proj.add_target_name(names(:agaricus))
    proj.add_target_location(locations(:burbank))
    obs = observations(:falmouth_2023_09_obs) # Boletus, Falmouth — neither
    User.current = user

    html = render_form(
      observation: obs, user: user, mode: :update,
      projects: [proj], project_checks: { proj.id => true },
      suspect_checked_projects: [proj]
    )

    assert_includes(html, :form_observations_projects_out_of_range.l)
    assert_includes(html, proj.title)
    assert_includes(html, :form_observations_projects_kind_target_name.l)
    assert_includes(html, :form_observations_projects_kind_target_location.l)
    # Old-style "(Dates: Any; Location: )" annotation should be gone.
    assert_no_match(/Dates: Any/, html)
    # Help text reflects the new wording.
    assert_includes(
      html,
      "Change the observation to align with project requirements"
    )
  end

  private

  def render_form(observation:, user:, mode: :create, **extras)
    User.current = user
    render(Components::ObservationForm.new(
             observation,
             mode: mode,
             user: user,
             good_images: [],
             exif_data: {},
             projects: [],
             project_checks: {},
             lists: [],
             list_checks: {},
             error_checked_projects: [],
             suspect_checked_projects: [],
             **extras
           ))
  end
end
