# frozen_string_literal: true

require("test_helper")

# Controller tests for checklists
class ChecklistsControllerTest < FunctionalTestCase
  # Prove that Life List goes to correct page which has correct content
  def test_checklist_for_user
    login
    user = users(:rolf)
    expect = Name.joins(observations: :user).
             where(Observation[:user_id] == user.id).
             where(Name[:rank] == Name.ranks[:Species]).distinct

    get(checklist_path(user_id: user.id))
    assert_match(/Checklist for #{user.name}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Species List checklist goes to correct page with correct content
  def test_checklist_for_species_list
    login
    list = species_lists(:one_genus_three_species_list)
    expect = Name.joins(observations: :species_list_observations).
             where(SpeciesListObservation[:species_list_id] == list.id).
             where(Name[:rank] == Name.ranks[:Species]).distinct

    get(checklist_path(species_list_id: list.id))
    assert_match(/Checklist for #{list.title}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Project checklist goes to correct page with correct content
  def test_checklist_for_project
    login
    project = projects(:one_genus_two_species_project)
    expect = Name.joins(observations: :project_observations).
             where(ProjectObservation[:project_id] == project.id).
             where(Name[:rank] == Name.ranks[:Species]).distinct

    get(checklist_path(project_id: project.id))
    assert_match(/Checklist for #{project.title}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Site checklist goes to correct page with correct content
  def test_checklist_for_site
    login
    expect = Name.joins(:observations).with_rank(:Species).distinct

    get(checklist_path)
    assert_match(/Checklist for #{:app_title.l}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  def prove_checklist_content(expect)
    # Get expected names not included in the displayed checklist links.
    missing_names = (
      expect.each_with_object([]) do |taxon, missing|
        next if /#{taxon.text_name}/.match?(css_select(".checklist a").text)

        missing << taxon.text_name
      end
    )

    assert_select(".checklist a", count: expect.size)
    assert(missing_names.empty?, "Species List missing #{missing_names}")
  end
end