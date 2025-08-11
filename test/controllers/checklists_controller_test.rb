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
