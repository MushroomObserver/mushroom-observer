# frozen_string_literal: true

require "test_helper"

class ProjectViolationsFormTest < ComponentTestCase
  def setup
    super
    @project = projects(:falmouth_2023_09_project)
    @admin = @project.user
  end

  def test_renders_one_row_per_violation
    violations = @project.violations
    html = render_form(violations: violations)

    violations.each do |v|
      assert_html(html, "a[href*='#{v.obs.id}']")
    end
    assert_html(html, "table.project-violations")
    # tbody has one row per violation (header tr lives in thead)
    body = html.scan(%r{<tbody>(.*?)</tbody>}m).first.first
    assert_equal(violations.size, body.scan("<tr").size)
  end

  def test_renders_kind_labels_per_row
    violations = @project.violations
    html = render_form(violations: violations)

    violations.each do |v|
      v.kinds.each do |kind|
        assert_includes(html, :"form_violations_kind_#{kind}".l)
      end
    end
  end

  def test_violations_sorted_by_sort_name_in_render
    violations = @project.violations
    html = render_form(violations: violations)

    rendered_ids = html.scan(/observation_link_(\d+)/).flatten.map(&:to_i).uniq
    expected_ids = violations.map { |v| v.obs.id }
    assert_equal(expected_ids, rendered_ids,
                 "Rows should render in violations order (sort_name asc)")
  end

  def test_no_violations_message
    proj = projects(:eol_project)
    html = render_form(project: proj, violations: [], user: proj.user)

    assert_includes(html, :form_violations_no_violations.l)
    assert_no_html(html, "table")
  end

  def test_admin_sees_exclude_buttons
    violations = @project.violations
    html = render_form(violations: violations)

    # button_to renders a <form method=post> with a hidden _method=put
    # and a <button type=submit>Label</button>.
    assert_includes(html, :form_violations_action_exclude.l)
    assert_html(html, "form.button_to[action$='/violations']")
    assert_html(html,
                "input[type='hidden'][name='project[do]'][value='exclude']")
    assert_html(html, "input[type='hidden'][name='_method'][value='put']")
  end

  def test_admin_sees_extend_button_on_date_violation
    proj = setup_date_violation_project
    date_v = proj.violations.find { |v| v.kinds.include?(:date) }
    assert(date_v, "Setup must produce a date violation")

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)

    assert_includes(html, :form_violations_action_extend.l)
    assert_html(html,
                "input[type='hidden'][name='project[do]'][value='extend']")
  end

  def test_admin_sees_add_target_name_button_on_target_name_violation
    proj = setup_target_name_violation_project
    name_v = proj.violations.find { |v| v.kinds.include?(:target_name) }
    assert(name_v, "Setup must produce a target_name violation")

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)

    assert_includes(html, :form_violations_action_add_target_name.l)
    assert_html(html,
                "input[type='hidden'][name='project[do]']" \
                "[value='add_target_name']")
  end

  def test_target_location_modal_renders_for_admin
    proj = setup_target_location_violation_project
    target_loc_v =
      proj.violations.find { |v| v.kinds.include?(:target_location) }
    assert(target_loc_v,
           "Setup must produce a target_location violation; check Burbank " \
           "vs Falmouth fixture pairing")

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)
    obs_id = target_loc_v.obs.id

    assert_html(html, "#location_target_modal_#{obs_id}.modal")
    assert_html(
      html,
      "#location_target_modal_#{obs_id} " \
      "input[type='hidden'][name='project[do]']" \
      "[value='add_target_location']"
    )
    assert_html(
      html,
      "#location_target_modal_#{obs_id} " \
      "input[type='hidden'][name='project[obs_id]'][value='#{obs_id}']"
    )
    # Modal trigger button is rendered too.
    assert_includes(html, :form_violations_action_add_target_location.l)
  end

  # Covers the `suffixes.empty?` branch of render_location_modal_body —
  # when the obs's location yields no usable suffixes (the only practical
  # case after the J1 fix is a country-only string like "USA"), the modal
  # body shows the "no usable suffixes" message and a Cancel button
  # without rendering a submit form.
  def test_target_location_modal_no_suffixes_message_for_country_only_where
    proj = setup_target_location_violation_project
    target_loc_v =
      proj.violations.find { |v| v.kinds.include?(:target_location) }
    assert(target_loc_v, "Setup must produce a target_location violation")

    obs = target_loc_v.obs
    obs.update!(location_id: nil, where: "USA")

    proj.reload
    refreshed = proj.violations.find { |v| v.obs.id == obs.id }
    assert(refreshed,
           "Obs should still violate target_location after where=USA")

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)
    modal_id = "location_target_modal_#{obs.id}"

    assert_html(html, "##{modal_id}.modal")
    assert_includes(
      html, :form_violations_modal_target_location_no_suffixes.l,
      "Modal body should show the no-usable-suffixes message"
    )
    assert_html(html, "##{modal_id} .modal-footer button[data-dismiss='modal']")
    assert_no_html(
      html,
      "##{modal_id} input[name='project[do]'][value='add_target_location']",
      "Empty-suffixes branch must not render an add_target_location form"
    )
  end

  def test_target_location_modal_excludes_country_suffix
    proj = setup_target_location_violation_project
    target_loc_v =
      proj.violations.find { |v| v.kinds.include?(:target_location) }
    assert(target_loc_v, "Setup must produce a target_location violation")

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)
    obs = target_loc_v.obs
    place = obs.location_id ? obs.location.name : obs.where
    bare_country = place.split(",").last&.strip

    skip_if_no_country = bare_country.blank? ||
                         Location.understood_countries.exclude?(bare_country)
    assert_not(skip_if_no_country,
               "Test setup expects fixture with a country tail (got: #{place})")

    assert_no_html(
      html,
      "input[type='radio'][value='#{bare_country}']",
      "Bare-country suffix should not appear as a selectable radio"
    )
  end

  def test_non_admin_only_sees_exclude_for_own_obs
    proj = setup_date_violation_project
    own_violation = proj.violations.find { |v| v.obs.user_id == users(:roy).id }
    others_violation =
      proj.violations.find { |v| v.obs.user_id != users(:roy).id }
    assert(own_violation && others_violation,
           "Setup must yield violations from the test user and someone else")

    html = render_form(project: proj, violations: proj.violations,
                       user: users(:roy))

    # Exclude button is keyed by obs_id; the form contains an
    # `input[name='project[obs_id]'][value='<id>']`. After the
    # namespacing pass, all action params live under `project[...]`
    # so they share a single dispatch shape in the controller.
    assert_html(
      html,
      "input[name='project[obs_id]'][value='#{own_violation.obs.id}']"
    )
    assert_no_html(
      html,
      "input[name='project[obs_id]'][value='#{others_violation.obs.id}']",
      "Other user's obs should not have an Exclude form for non-admin"
    )
    # Admin-only actions are not rendered for non-admin.
    assert_no_html(html, "input[value='extend']")
    assert_no_html(html, "input[value='add_target_name']")
    assert_no_html(html, "input[value='add_target_location']")
  end

  def test_target_location_modal_offers_create_for_missing_location
    proj = setup_target_location_violation_project
    target_loc_v =
      proj.violations.find { |v| v.kinds.include?(:target_location) }
    assert(target_loc_v, "Setup must produce a target_location violation")

    obs = target_loc_v.obs
    place = obs.location_id ? obs.location.name : obs.where
    place_parts = place.split(",").map(&:strip)
    # Pick the most-specific suffix that has multiple comma segments
    # and isn't a bare country.
    candidate_suffix = place_parts[1..].join(", ")
    return if candidate_suffix.blank? ||
              Location.understood_countries.include?(candidate_suffix)
    return if Location.find_by(name: candidate_suffix)

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)

    # Disabled radio plus a Create link to /locations/new with the suffix.
    assert_html(html, "input[type='radio'][disabled]")
    assert_html(
      html,
      "a[href^='/locations/new?display_name='][target='_blank']"
    )
  end

  # Coverage gaps surfaced in audit of merged #4277: the existing-
  # location branch of `suffix_choices`, the `suffix_create_link`
  # attributes, the `render_suffix_radios` help-text emission, and
  # the `first_existing` preselect (the Copilot review fix).

  def test_existing_location_suffix_renders_enabled_radio_with_id
    # When a comma-suffix of the obs's location matches an existing
    # Location, render an ENABLED radio whose value is that
    # location's id (NOT disabled, no `append:` Create link). This
    # is the other branch of `suffix_choices` — currently uncovered.
    proj = setup_target_location_violation_project
    target_loc_v =
      proj.violations.find { |v| v.kinds.include?(:target_location) }
    obs = target_loc_v.obs

    # Find at least one suffix of the obs's location that matches an
    # existing Location. If none, the test scenario isn't satisfiable
    # for the current fixture state — skip.
    place = obs.location_id ? obs.location.name : obs.where
    suffixes = place.split(",").each_index.map do |i|
      place.split(",")[i..].join(",").strip
    end
    existing = Location.where(name: suffixes).first
    skip("No fixture location matches a suffix of #{place.inspect}") \
      unless existing

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)

    # Radio for the existing-location row: value=location.id, enabled.
    assert_html(
      html,
      "#location_target_modal_#{obs.id} " \
      "input[type='radio'][value='#{existing.id}']:not([disabled])"
    )
  end

  def test_suffix_create_link_has_target_blank_and_btn_class
    proj = setup_target_location_violation_project

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)

    # The Create link on placeholder rows: target="_blank" +
    # rel="noopener" (so the popup can't manipulate opener) +
    # `.btn-default.btn-xs` styling. Currently only target="_blank"
    # was asserted by the existing test.
    assert_html(
      html,
      "a[target='_blank'][rel='noopener'].btn.btn-default.btn-xs"
    )
  end

  def test_suffix_radios_render_help_paragraph
    proj = setup_target_location_violation_project

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)

    # Help paragraph rendered above the radio group (inside the
    # modal-body). Wrapped in a `<p>`, not just plain text — without
    # this users see a list of radios with no explanation.
    assert_html(html, "p", text: :form_violations_modal_target_location_help.l)
  end

  private

  def render_form(violations:, project: @project, user: @admin)
    render(Components::ProjectViolationsForm.new(
             project: project, violations: violations, user: user
           ))
  end

  # Project keyed only on date constraints, with a roy-owned obs out of
  # range so test_non_admin_only_sees_exclude_for_own_obs has a target.
  def setup_date_violation_project
    proj = projects(:falmouth_2023_09_project)
    # Falmouth project already has multi-user violations; make sure
    # there's at least one obs owned by `roy`.
    roy_obs = observations(:nybg_2023_09_obs)
    roy_obs.update!(user: users(:roy)) unless roy_obs.user == users(:roy)
    proj
  end

  def setup_target_name_violation_project
    proj = projects(:rare_fungi_project)
    proj.project_target_locations.destroy_all
    proj.project_target_names.destroy_all
    proj.update!(start_date: nil, end_date: nil, location: nil)
    proj.add_target_name(names(:agaricus))
    off_target = observations(:peltigera_obs)
    proj.add_observation(off_target)
    proj
  end

  def setup_target_location_violation_project
    proj = projects(:rare_fungi_project)
    # rare_fungi_project already has burbank as a target_location via
    # rare_fungi_target_burbank fixture; clear and re-add to be explicit.
    proj.project_target_locations.destroy_all
    proj.add_target_location(locations(:burbank))
    proj.update!(start_date: nil, end_date: nil, location: nil)
    proj.project_target_names.destroy_all
    elsewhere = observations(:falmouth_2023_09_obs)
    proj.add_observation(elsewhere)
    proj
  end
end
