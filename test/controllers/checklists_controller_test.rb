# frozen_string_literal: true

require("test_helper")

# Controller tests for checklists
class ChecklistsControllerTest < FunctionalTestCase
  # Prove that Life List goes to correct page which has correct content
  def test_checklist_for_user
    login
    user = users(:rolf)
    expect = Name.joins(:observations).
             where({ observations: { user_id: user.id } }).distinct

    get(:show, params: { user_id: user.id })
    assert_match(/Checklist for #{user.name}/, css_select("title").text,
                 "Wrong page")
    prove_checklist_content(expect)
  end

  def test_checklist_marks_deprecated
    login
    observation = Observation.joins(:name).find_by(name: { deprecated: true })
    user = observation.user
    get(:show, params: { user_id: user.id })
    assert_match(") *</a>", @response.body)
  end

  # Prove that Species List checklist goes to correct page with correct content
  def test_checklist_for_species_list
    login("mary")
    list = species_lists(:one_genus_three_species_list)
    expect = Name.joins(observations: :species_list_observations).
             where({ species_list_observations: { species_list_id: list.id } }).
             distinct

    get(:show, params: { species_list_id: list.id })
    assert_match(/Checklist for #{list.title}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Project checklist goes to correct page with correct content
  def test_checklist_for_project
    login
    project = projects(:one_genus_two_species_project)
    expect = Name.joins(observations: :project_observations).
             where({ observations: { project_observations:
                      { project_id: project.id } } }).distinct

    get(:show, params: { project_id: project.id })
    assert_match(/\(1\)/, @response.body)

    prove_checklist_content(expect)
  end

  def test_checklist_for_project_location
    login
    project = projects(:one_genus_two_species_project)
    location = locations(:burbank)
    expect = Name.joins(observations: :project_observations).
             where({ observations:
                         { project_observations: { project_id: project.id },
                           location: location } }).distinct

    get(:show, params: { project_id: project.id, location_id: location.id })
    assert_match(/\(1\)/, @response.body)
    assert_match("location%3A#{location.id}", @response.body)
    assert_match(/#{:checklist_for.t}/, @response.body)
    assert_select("li.nav-item") do
      assert_select(
        "a.nav-link.active[href='/projects/#{project.id}/locations']",
        text: /Locations/
      )
    end
    prove_checklist_content(expect)
  end

  # Issue #4128 — Target/summary copy and three-panel layout for a project
  # with target names and a mix of observed / unobserved targets.
  def test_checklist_for_project_renders_target_summary_and_panels
    project = projects(:rare_fungi_project)
    # Observe one target (species-level). The other target stays unobserved.
    obs = Observation.create!(
      name: names(:coprinus_comatus),
      user: users(:rolf),
      when: Time.zone.now
    )
    project.observations << obs

    login
    get(:show, params: { project_id: project.id })

    assert_response(:success)
    # Line 1 — target-name summary.
    assert_match(/2 target names.*1 observed.*1 not yet observed/,
                 @response.body)
    # Line 2 — observed summary with synonyms-counted-once note.
    assert_match(/1 species and 0 higher-level taxa observed/,
                 @response.body)
    # The two panels expected for this setup (one observed species
    # target + one unobserved target) render with their distinctive
    # headers. No higher-level taxa in this fixture, so that panel is
    # legitimately absent.
    assert_match(/Unobserved target names/, @response.body)
    assert_match(/Species-level taxa/, @response.body)
    assert_select("#checklist_unobserved_panel")
    assert_select("#checklist_species_panel")
    assert_select("#checklist_higher_panel", count: 0)
    # Legend entry for the red X remove button (admin-only).
    assert_match(/Remove this target name from the project/, @response.body)
    # Unobserved-target name link goes to the name page (a project-scoped
    # observation search would always be empty). Observed-target name
    # link still goes to the observations search.
    unobserved_id = names(:agaricus_campestris).id
    observed_id = names(:coprinus_comatus).id
    assert_select("#checklist_unobserved_panel a[href='/names/#{unobserved_id}']")
    assert_select(
      "#checklist_species_panel a[href^='/observations?pattern='][href*='name%3A#{observed_id}']"
    )
  end

  def test_checklist_footnote_hidden_from_non_admin
    project = projects(:rare_fungi_project)
    login("mary") # mary is not an admin of rare_fungi_project
    get(:show, params: { project_id: project.id })

    assert_response(:success)
    assert_no_match(/Remove this target name from the project/, @response.body)
  end

  # Prove that Site checklist goes to correct page with correct content
  def test_checklist_for_site
    login
    expect = Name.joins(:observations).distinct

    get(:show)
    assert_match(/Checklist for #{:app_title.l}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  def prove_checklist_content(expect)
    # Get expected names not included in the displayed checklist links.
    missing_names = expect.each_with_object([]) do |taxon, missing|
      next if /#{taxon.text_name}/.match?(css_select(".checklist a").text)

      missing << taxon.text_name
    end

    assert_select(".checklist a", count: expect.size)
    assert(missing_names.empty?, "Species List missing #{missing_names}")
  end
end
