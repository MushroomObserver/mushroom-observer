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
    assert_no_match(/<table/, html)
  end

  def test_admin_sees_exclude_buttons
    violations = @project.violations
    html = render_form(violations: violations)

    # button_to renders a <form method=post> with a hidden _method=put
    # and a <button type=submit>Label</button>.
    assert_includes(html, :form_violations_action_exclude.l)
    assert_html(html, "form.button_to[action$='/violations']")
    assert_html(html, "input[type='hidden'][name='do'][value='exclude']")
    assert_html(html, "input[type='hidden'][name='_method'][value='put']")
  end

  def test_admin_sees_extend_button_on_date_violation
    proj = setup_date_violation_project
    date_v = proj.violations.find { |v| v.kinds.include?(:date) }
    assert(date_v, "Setup must produce a date violation")

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)

    assert_includes(html, :form_violations_action_extend.l)
    assert_html(html, "input[type='hidden'][name='do'][value='extend']")
  end

  def test_admin_sees_add_target_name_button_on_target_name_violation
    proj = setup_target_name_violation_project
    name_v = proj.violations.find { |v| v.kinds.include?(:target_name) }
    assert(name_v, "Setup must produce a target_name violation")

    html = render_form(project: proj, violations: proj.violations,
                       user: proj.user)

    assert_includes(html, :form_violations_action_add_target_name.l)
    assert_html(html,
                "input[type='hidden'][name='do'][value='add_target_name']")
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
      "input[type='hidden'][name='do'][value='add_target_location']"
    )
    assert_html(
      html,
      "#location_target_modal_#{obs_id} " \
      "input[type='hidden'][name='obs_id'][value='#{obs_id}']"
    )
    # Modal trigger button is rendered too.
    assert_includes(html, :form_violations_action_add_target_location.l)
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

    assert_no_match(
      /<input[^>]*type="radio"[^>]*value="#{Regexp.escape(bare_country)}"/,
      html,
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
    # `input[name='obs_id'][value='<id>']`.
    assert_match(
      /name="obs_id"[^>]*value="#{own_violation.obs.id}"/, html,
      "Own obs should have an Exclude form"
    )
    assert_no_match(
      /name="obs_id"[^>]*value="#{others_violation.obs.id}"/, html,
      "Other user's obs should not have an Exclude form for non-admin"
    )
    # Admin-only actions are not rendered for non-admin.
    assert_no_match(/value="extend"/, html)
    assert_no_match(/value="add_target_name"/, html)
    assert_no_match(/value="add_target_location"/, html)
  end

  # Regression for J1 of PR #4182 review: a 2-part location like
  # "California, USA" should yield the full name as a candidate. The
  # earlier (1..) range produced an empty list after the bare-country
  # filter and the modal showed "Use Exclude instead", which made no
  # sense for a state-level target.
  def test_comma_suffixes_includes_full_name
    component = Components::ProjectViolationsForm.new(
      project: projects(:rare_fungi_project),
      violations: [],
      user: rolf
    )

    assert_equal(["California, USA", "USA"],
                 component.send(:comma_suffixes, "California, USA"))
    assert_equal(
      ["Berkeley, Alameda Co., California, USA",
       "Alameda Co., California, USA", "California, USA", "USA"],
      component.send(:comma_suffixes,
                     "Berkeley, Alameda Co., California, USA")
    )
    assert_equal([], component.send(:comma_suffixes, ""))
    assert_equal(["USA"], component.send(:comma_suffixes, "USA"))
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
    assert_match(
      %r{<a [^>]*href="/locations/new\?display_name=[^"]*"[^>]*target="_blank"},
      html, "Create link to /locations/new should appear for missing suffix"
    )
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
