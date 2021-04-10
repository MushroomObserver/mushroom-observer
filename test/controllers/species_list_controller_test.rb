# frozen_string_literal: true

require("test_helper")

class SpeciesListControllerTest < FunctionalTestCase
  # Score for one new name.
  def v_nam
    10
  end

  # Score for one species list.
  def v_spl
    5
  end

  # Score for one observation:
  #   species_list entry  1
  #   observation         1
  #   naming              1
  #   vote                1
  def v_obs
    4
  end

  def spl_params(spl)
    {
      id: spl.id,
      species_list: {
        place_name: spl.place_name,
        title: spl.title,
        "when(1i)" => spl.when.year.to_s,
        "when(2i)" => spl.when.month.to_s,
        "when(3i)" => spl.when.day.to_s,
        notes: spl.notes
      },
      list: { members: "" },
      checklist_data: {},
      member: { notes: Observation.no_notes }
    }
  end

  # Controller specific asserts
  MODIFY_PARTIALS = %w[_form_list_feedback _textilize_help _form_species_lists].
                    freeze

  def assert_create_species_list
    assert_action_partials("create_species_list", MODIFY_PARTIALS)
  end

  def assert_edit_species_list
    assert_action_partials("edit_species_list", MODIFY_PARTIALS)
  end

  def assert_project_checks(project_states)
    project_states.each do |id, state|
      assert_checkbox_state("project_id_#{id}", state)
    end
  end

  def assigns_exist
    !assigns(:all_lists).empty?
  rescue StandardError
  end

  def init_for_project_checkbox_tests
    @proj1 = projects(:eol_project)
    @proj2 = projects(:bolete_project)
    @spl1 = species_lists(:first_species_list)
    @spl2 = species_lists(:unknown_species_list)
    assert_users_equal(rolf, @spl1.user)
    assert_users_equal(mary, @spl2.user)
    assert_obj_list_equal([], @spl1.projects)
    assert_obj_list_equal([@proj2], @spl2.projects)
    assert_obj_list_equal([rolf, mary, katrina], @proj1.user_group.users)
    assert_obj_list_equal([dick], @proj2.user_group.users)
  end

  def obs_params(obs, vote)
    {
      when_str: obs.when_str,
      place_name: obs.place_name,
      notes: obs.notes,
      lat: obs.lat,
      long: obs.long,
      alt: obs.alt,
      is_collection_location: obs.is_collection_location ? "1" : "0",
      specimen: obs.specimen ? "1" : "0",
      value: vote
    }
  end

  ##############################################################################

  def test_index_species_list_by_past_bys
    get(:index_species_list, params: { by: :modified })
    assert_response(:success)
    get(:index_species_list, params: { by: :created })
    assert_response(:success)
  end

  def test_list_species_lists
    get(:list_species_lists)
    assert_template(:list_species_lists)
  end

  def test_show_species_list
    sl_id = species_lists(:first_species_list).id

    # Show empty list with no one logged in.
    get(:show_species_list, id: sl_id)
    assert_template(:show_species_list, partial: "_show_comments")

    # Show same list with non-owner logged in.
    login("mary")
    get(:show_species_list, id: sl_id)
    assert_template(:show_species_list, partial: "_show_comments")

    # Show non-empty list with owner logged in.
    get(:show_species_list,
        id: species_lists(:unknown_species_list).id)
    assert_template(:show_species_list, partial: "_show_comments")
  end

  def test_show_species_lists_attached_to_projects
    proj1 = projects(:eol_project)
    proj2 = projects(:bolete_project)
    spl = species_lists(:first_species_list)
    assert_obj_list_equal([], spl.projects)

    get(:show_species_list, params: { id: spl.id })
    assert_no_match(proj1.title.t, @response.body)
    assert_no_match(proj2.title.t, @response.body)

    proj1.add_species_list(spl)
    get(:show_species_list, params: { id: spl.id })
    assert_match(proj1.title.t, @response.body)
    assert_no_match(proj2.title.t, @response.body)

    proj2.add_species_list(spl)
    get(:show_species_list, params: { id: spl.id })
    assert_match(proj1.title.t, @response.body)
    assert_match(proj2.title.t, @response.body)
  end

  def test_show_species_list_edit_links
    spl = species_lists(:unknown_species_list)
    proj = projects(:bolete_project)
    assert_equal(mary.id, spl.user_id)            # owned by mary
    assert(spl.projects.include?(proj))           # owned by bolete project
    assert_equal([dick.id],
                 proj.user_group.users.map(&:id)) # dick is only project member

    login("rolf")
    get(:show_species_list, params: { id: spl.id })
    assert_select("a[href*=edit_species_list]", count: 0)
    assert_select("a[href*=destroy_species_list]", count: 0)
    get(:edit_species_list, params: { id: spl.id })
    assert_response(:redirect)
    get(:destroy_species_list, params: { id: spl.id })
    assert_flash_error

    login("mary")
    get(:show_species_list, params: { id: spl.id })
    assert_select("a[href*=edit_species_list]", minimum: 1)
    assert_select("a[href*=destroy_species_list]", minimum: 1)
    get(:edit_species_list, params: { id: spl.id })
    assert_response(:success)

    login("dick")
    get(:show_species_list, params: { id: spl.id })
    assert_select("a[href*=edit_species_list]", minimum: 1)
    assert_select("a[href*=destroy_species_list]", minimum: 1)
    get(:edit_species_list, params: { id: spl.id })
    assert_response(:success)
    get(:destroy_species_list, params: { id: spl.id })
    assert_flash_success
  end

  def test_species_lists_by_title
    get(:species_lists_by_title)
    assert_template(:list_species_lists)
  end

  def test_species_lists_by_user
    get(:species_lists_by_user, id: rolf.id)
    assert_template(:list_species_lists)
  end

  def test_species_lists_for_project
    get(:species_lists_for_project,
        id: projects(:bolete_project).id)
    assert_template(:list_species_lists)
  end

  def test_species_list_search
    spl = species_lists(:unknown_species_list)
    get(:species_list_search, params: { pattern: spl.id.to_s })
    assert_redirected_to(action: :show_species_list, id: spl.id)

    get(:species_list_search, params: { pattern: "mysteries" })
    assert_response(:redirect)
  end

  def test_list_species_list_by_user
    query = Query.lookup_and_save(:SpeciesList, :all, by: "reverse_user")
    query_params = @controller.query_params(query)
    get(:index_species_list, query_params)
    assert_template(:list_species_lists)

    get(:next_species_list, query_params.merge(id: query.result_ids[0]))
    assert_redirected_to(query_params.merge(action: "show_species_list",
                                            id: query.result_ids[1]))

    get(:prev_species_list, query_params.merge(id: query.result_ids[1]))
    assert_redirected_to(query_params.merge(action: "show_species_list",
                                            id: query.result_ids[0]))
  end

  def test_destroy_species_list
    spl = species_lists(:first_species_list)
    assert(spl)
    id = spl.id
    params = { id: id.to_s }
    assert_equal("rolf", spl.user.login)
    requires_user(:destroy_species_list, [:show_species_list], params)
    assert_redirected_to(action: :list_species_lists)
    assert_raises(ActiveRecord::RecordNotFound) do
      SpeciesList.find(id)
    end
  end

  def test_manage_species_lists
    obs = observations(:coprinus_comatus_obs)
    params = { id: obs.id.to_s }
    requires_login(:manage_species_lists, params)

    assert(assigns_exist, "Missing species lists!")
  end

  def test_add_observation_to_species_list
    sp = species_lists(:first_species_list)
    obs = observations(:coprinus_comatus_obs)
    assert_not(sp.observations.member?(obs))
    params = { species_list: sp.id, observation: obs.id }
    requires_login(:add_observation_to_species_list, params)
    assert_redirected_to(action: :manage_species_lists, id: obs.id)
    assert(sp.reload.observations.member?(obs))
  end

  def test_add_observation_to_species_list_no_permission
    sp = species_lists(:first_species_list)
    obs = observations(:coprinus_comatus_obs)
    assert_not(sp.observations.member?(obs))
    params = { species_list: sp.id, observation: obs.id }
    login("dick")
    get(:add_observation_to_species_list, params)
    assert_redirected_to(action: :show_species_list, id: sp.id)
    assert_not(sp.reload.observations.member?(obs))
  end

  def test_remove_observation_from_species_list
    spl = species_lists(:unknown_species_list)
    obs = observations(:minimal_unknown_obs)
    assert(spl.observations.member?(obs))
    params = { species_list: spl.id, observation: obs.id }
    owner = spl.user.login
    assert_not_equal("rolf", owner)

    # Try with non-owner (can't use requires_user since failure is a redirect)
    # effectively fails and gets redirected to show_species_list
    requires_login(:remove_observation_from_species_list, params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert(spl.reload.observations.member?(obs))

    login(owner)
    get(:remove_observation_from_species_list, params)
    assert_redirected_to(action: "manage_species_lists", id: obs.id)
    assert_not(spl.reload.observations.member?(obs))
  end

  def test_manage_species_list_with_projects
    proj = projects(:bolete_project)
    spl1 = species_lists(:unknown_species_list)
    spl2 = species_lists(:first_species_list)
    spl3 = species_lists(:another_species_list)
    spl2.user = dick
    spl2.save
    spl2.reload
    obs1 = observations(:detailed_unknown_obs)
    obs2 = observations(:coprinus_comatus_obs)
    assert_obj_list_equal([dick], proj.user_group.users)
    assert_obj_list_equal([proj], spl1.projects)
    assert_obj_list_equal([], spl2.projects)
    assert_obj_list_equal([], spl3.projects)
    assert_true(spl1.observations.include?(obs1))
    assert_false(spl1.observations.include?(obs2))
    assert_obj_list_equal([], spl2.observations)
    assert_obj_list_equal([], spl3.observations)
    assert_users_equal(mary, spl1.user)
    assert_users_equal(dick, spl2.user)
    assert_users_equal(rolf, spl3.user)

    login("dick")
    get(:manage_species_lists, params: { id: obs1.id })
    assert_select("a[href*='species_list=#{spl1.id}']",
                  text: :REMOVE.t, count: 1)
    assert_select("a[href*='species_list=#{spl2.id}']", text: :ADD.t, count: 1)
    assert_select("a[href*='species_list=#{spl3.id}']", count: 0)

    get(:manage_species_lists, params: { id: obs2.id })
    assert_select("a[href*='species_list=#{spl1.id}']", text: :ADD.t, count: 1)
    assert_select("a[href*='species_list=#{spl2.id}']", text: :ADD.t, count: 1)
    assert_select("a[href*='species_list=#{spl3.id}']", count: 0)

    post(:add_observation_to_species_list,
         params: { observation: obs2.id,
                   species_list: spl1.id })
    assert_redirected_to(action: :manage_species_lists, id: obs2.id)
    assert_true(spl1.reload.observations.include?(obs2))

    post(:remove_observation_from_species_list,
         params: { observation: obs2.id,
                   species_list: spl1.id })
    assert_redirected_to(action: :manage_species_lists, id: obs2.id)
    assert_false(spl1.reload.observations.include?(obs2))
  end

  # ----------------------------
  #  Create lists.
  # ----------------------------

  def test_create_species_list
    requires_login(:create_species_list)
    assert_form_action(action: "create_species_list")
  end

  def test_create_species_list_member_notes_areas
    # Prove that only member_notes textarea is Other
    # for user without notes template
    user = users(:rolf)
    login(user.login)
    get(:create_species_list)
    assert_page_has_correct_notes_areas(
      klass: SpeciesList,
      expect_areas: { Observation.other_notes_key => "" }
    )

    # Prove that member_notes textareas are those for template plus Other
    # for user with notes template
    user = users(:notes_templater)
    login(user.login)
    get(:create_species_list)
    assert_page_has_correct_notes_areas(
      klass: SpeciesList,
      expect_areas: { Cap: "", Nearby_trees: "", odor: "",
                      Observation.other_notes_key => "" }
    )
  end

  def test_unsuccessful_create_location_description
    user = login("spamspamspam")
    assert_false(user.is_successful_contributor?)
    get(:create_species_list)
    assert_response(:redirect)
  end

  # Test constructing species lists in various ways.
  def test_construct_species_list
    list_title = "List Title"
    params = {
      list: { members: names(:coprinus_comatus).text_name },
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: "  " + list_title.sub(/ /, "  ") + "  ",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      }
    }
    post_requires_login(:create_species_list, params)
    spl = SpeciesList.last
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_spl + v_obs, rolf.reload.contribution)
    assert_not_nil(spl)
    assert_equal(list_title, spl.title)
    assert(spl.name_included(names(:coprinus_comatus)))
    obs = spl.observations.first
    assert_equal(Vote.maximum_vote, obs.namings.first.votes.first.value)
    assert(obs.vote_cache > 2)
    assert_equal(Observation.no_notes, obs.notes)
    assert_nil(obs.lat)
    assert_nil(obs.long)
    assert_nil(obs.alt)
    assert_equal(false, obs.is_collection_location)
    assert_equal(false, obs.specimen)
  end

  def test_construct_species_list_without_location
    list_title = "List Title"
    params = {
      list: { members: names(:coprinus_comatus).text_name },
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      }
    }
    post_requires_login(:create_species_list, params)
    spl = SpeciesList.last
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_objs_equal(Location.unknown, spl.location)
  end

  def test_construct_species_list_existing_genus
    agaricus = names(:agaricus)
    list_title = "List Title"
    params = {
      list: { members: "#{agaricus.rank} #{agaricus.text_name}" },
      checklist_data: {},
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      }
    }
    login("rolf")
    post(:create_species_list, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_spl + v_obs, rolf.reload.contribution)
    assert_not_nil(spl)
    assert(spl.name_included(agaricus))
  end

  def test_construct_species_list_new_family
    list_title = "List Title"
    rank = :Family
    new_name_str = "Lecideaceae"
    new_list_str = "#{rank} #{new_name_str}"
    assert_nil(Name.find_by(text_name: new_name_str))
    params = {
      list: { members: new_list_str },
      checklist_data: {},
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      },
      approved_names: new_list_str
    }
    login("rolf")
    post(:create_species_list, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(action: :show_species_list, id: spl.id)
    # Creates Lecideaceae, spl, and obs/naming/splentry.
    assert_equal(10 + v_nam + v_spl + v_obs, rolf.reload.contribution)
    assert_not_nil(spl)
    new_name = Name.find_by(text_name: new_name_str)
    assert_not_nil(new_name)
    assert_equal(rank, new_name.rank)
    assert(spl.name_included(new_name))
  end

  # <name> = <name> shouldn't work in construct_species_list
  def test_construct_species_list_synonym
    list_title = "List Title"
    name = names(:macrolepiota_rachodes)
    synonym_name = names(:lepiota_rachodes)
    assert_not(synonym_name.deprecated)
    assert_nil(synonym_name.synonym_id)
    params = {
      list: { members: "#{name.text_name} = #{synonym_name.text_name}" },
      checklist_data: {},
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      }
    }
    login("rolf")
    post(:create_species_list, params: params)
    assert_create_species_list
    assert_equal(10, rolf.reload.contribution)
    assert_not(synonym_name.reload.deprecated)
    assert_nil(synonym_name.synonym_id)
  end

  def test_construct_species_list_junk
    list_title = "List Title"
    new_name_str = "This is a bunch of junk"
    assert_nil(Name.find_by(text_name: new_name_str))
    params = {
      list: { members: new_name_str },
      checklist_data: {},
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      },
      approved_names: new_name_str
    }
    login("rolf")
    post(:create_species_list, params: params)
    assert_create_species_list
    assert_equal(10, rolf.reload.contribution)
    assert_nil(Name.find_by(text_name: new_name_str))
    assert_nil(SpeciesList.find_by(title: list_title))
  end

  def test_construct_species_list_double_space
    list_title = "Double Space List"
    new_name_str = "Lactarius rubidus  (Hesler and Smith) Methven"
    params = {
      list: { members: new_name_str },
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      },
      approved_names: new_name_str.squeeze(" ")
    }
    login("rolf")
    post(:create_species_list, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(action: :show_species_list, id: spl.id)
    # Creating L. rubidus (and spl and obs/splentry/naming).
    assert_equal(10 + v_nam + v_spl + v_obs, rolf.reload.contribution)
    assert_not_nil(spl)
    obs = spl.observations.first
    assert_not_nil(obs)
    assert_not_nil(obs.updated_at)
    name = Name.find_by(search_name: new_name_str.squeeze(" "))
    assert_not_nil(name)
    assert(spl.name_included(name))
  end

  def test_construct_species_list_rankless_taxon
    list_title = "List Title"
    new_name_str = "Lecideaceae"
    assert_nil(Name.find_by(text_name: new_name_str))
    params = {
      list: { members: new_name_str },
      checklist_data: {},
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      },
      approved_names: new_name_str
    }
    login("rolf")
    post(:create_species_list, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(action: :show_species_list, id: spl.id)
    # Creates Lecideaceae, spl, obs/naming/splentry.
    assert_equal(10 + v_nam + v_spl + v_obs, rolf.reload.contribution)
    assert_not_nil(spl)
    new_name = Name.find_by(text_name: new_name_str)
    assert_not_nil(new_name)
    assert_equal(:Family, new_name.rank)
    assert(spl.name_included(new_name))
  end

  # Rather than repeat everything done for update_species, this construct
  # species just does a bit of everything:
  #   Written in:
  #     Lactarius subalpinus (deprecated, approved)
  #     Amanita baccata      (ambiguous, checked Arora in radio boxes)
  #     New name             (new, approved from previous post)
  #   Checklist:
  #     Agaricus campestris  (checked)
  #     Lactarius alpigenes  (checked, deprecated, approved,
  #                           checked box for preferred name Lactarius alpinus)
  # Should result in the following list:
  #   Lactarius subalpinus
  #   Amanita baccata Arora
  #   New name
  #   Agaricus campestris
  #   Lactarius alpinus
  #   (but *NOT* L. alpingenes)
  def test_construct_species_list_extravaganza
    deprecated_name = names(:lactarius_subalpinus)
    list_members = [deprecated_name.text_name]
    multiple_name = names(:amanita_baccata_arora)
    list_members.push(multiple_name.text_name)
    new_name_str = "New name"
    list_members.push(new_name_str)
    assert_nil(Name.find_by(text_name: new_name_str))

    checklist_data = {}
    current_checklist_name = names(:agaricus_campestris)
    checklist_data[current_checklist_name.id.to_s] = "1"
    deprecated_checklist_name = names(:lactarius_alpigenes)
    approved_name = names(:lactarius_alpinus)
    checklist_data[deprecated_checklist_name.id.to_s] = "1"

    list_title = "List Title"
    params = {
      list: { members: list_members.join("\r\n") },
      checklist_data: checklist_data,
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "6",
        "when(3i)" => "4",
        notes: "List Notes"
      }
    }
    params[:approved_names] = new_name_str
    params[:chosen_multiple_names] =
      { multiple_name.id.to_s => multiple_name.id.to_s }
    params[:chosen_approved_names] =
      { deprecated_checklist_name.id.to_s => approved_name.id.to_s }
    params[:approved_deprecated_names] = [
      deprecated_name.id.to_s, deprecated_checklist_name.id.to_s
    ].join("\r\n")

    login("rolf")
    post(:create_species_list, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(action: :show_species_list, id: spl.id)
    # Creates "New" and "New name", spl, and five obs/naming/splentries.
    assert_equal(10 + v_nam * 2 + v_spl + v_obs * 5, rolf.reload.contribution)
    assert(spl.name_included(deprecated_name))
    assert(spl.name_included(multiple_name))
    assert(spl.name_included(Name.find_by(text_name: new_name_str)))
    assert(spl.name_included(current_checklist_name))
    assert_not(spl.name_included(deprecated_checklist_name))
    assert(spl.name_included(approved_name))
  end

  def test_construct_species_list_nonalpha_multiple
    # First try creating it with ambiguous name "Warnerbros bugs-bunny".

    # There are two such names with authors One and Two, respectively.
    # We don't know which Name has the lower autogenerated id.  So create a
    # variable so we can relate Name to Author
    bugs_names = Name.where(text_name: "Warnerbros bugs-bunny")

    params = {
      list: { members: "\n Warnerbros  bugs-bunny " },
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: "Testing nonalphas",
        "when(1i)" => "2008",
        "when(2i)" => "1",
        "when(3i)" => "31",
        notes: ""
      }
    }
    login("rolf")
    post(:create_species_list, params: params)
    assert_create_species_list
    assert_equal(10, rolf.reload.contribution)
    assert_equal("Warnerbros bugs-bunny",
                 @controller.instance_variable_get("@list_members"))
    assert_equal([], @controller.instance_variable_get("@new_names"))
    assert_equal([bugs_names.first],
                 @controller.instance_variable_get("@multiple_names"))
    assert_equal([], @controller.instance_variable_get("@deprecated_names"))

    # Now re-post, having selected the other Bugs Bunny name.
    params = {
      list: { members: "Warnerbros bugs-bunny\r\n" },
      member: { notes: Observation.no_notes },
      species_list: {
        place_name: "Burbank, California, USA",
        title: "Testing nonalphas",
        "when(1i)" => "2008",
        "when(2i)" => "1",
        "when(3i)" => "31",
        notes: ""
      },
      chosen_multiple_names: { bugs_names.first.id.to_s =>
                               bugs_names.second.id }
    }
    post(:create_species_list, params: params)
    spl = SpeciesList.last

    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_spl + v_obs, rolf.reload.contribution)
    assert(spl.name_included(bugs_names.second))
  end

  # Test constructing species lists, tweaking member fields.
  def test_construct_species_list_with_member_fields
    list_title = "List Title"
    params = {
      list: { members: names(:coprinus_comatus).text_name },
      member: {
        vote: Vote.minimum_vote,
        notes: { Observation.other_notes_key => "member notes" },
        lat: "12 34 56 N",
        long: "78 9 12 W",
        alt: "345 ft",
        is_collection_location: "1",
        specimen: "1"
      },
      species_list: {
        place_name: "Burbank, California, USA",
        title: list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      }
    }
    post_requires_login(:create_species_list, params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_spl + v_obs, rolf.reload.contribution)
    assert_not_nil(spl)
    assert(spl.name_included(names(:coprinus_comatus)))
    obs = spl.observations.first
    assert_equal(Vote.minimum_vote, obs.namings.first.votes.first.value)
    assert_equal([Observation.other_notes_key], obs.notes.keys)
    assert_equal(obs.notes[Observation.other_notes_key], "member notes")
    assert_equal(12.5822, obs.lat)
    assert_equal(-78.1533, obs.long)
    assert_equal(105, obs.alt)
    assert_equal(true, obs.is_collection_location)
    assert_equal(true, obs.specimen)
  end

  def test_create_blank_year
    params = {
      species_list: {
        place_name: "Earth",
        title: "List without year",
        "when(1i)" => "", # year
        "when(2i)" => "3",
        "when(3i)" => "14",
      }
    }
    login("rolf")
    post(:create_species_list, params: params)
    spl = SpeciesList.last

    assert_equal(
      spl.created_at.to_date, spl.when,
      "SpeciesList.when should be current date if user makes When year blank"
    )
  end

  # -----------------------------------------------
  #  Test changing species lists in various ways.
  # -----------------------------------------------

  def test_edit_species_list
    spl = species_lists(:first_species_list)
    params = { id: spl.id.to_s }
    assert_equal("rolf", spl.user.login)
    requires_user(:edit_species_list, :show_species_list, params)
    assert_edit_species_list
    assert_form_action(action: "edit_species_list", id: spl.id.to_s,
                       approved_where: "Burbank, California, USA")
  end

  def test_update_species_list_nochange
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    post_requires_user(:edit_species_list, :show_species_list, params,
                       spl.user.login)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
  end

  def test_update_species_list_text_add_multiple
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus\r\nAgaricus campestris"
    owner = spl.user.login
    assert_not_equal("rolf", owner)

    login("rolf")
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10, rolf.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)

    login(owner)
    post(:edit_species_list, params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_obs * 2, spl.user.reload.contribution)
    assert_equal(sp_count + 2, spl.reload.observations.size)
  end

  # This was intended to catch a bug seen in the wild, but it doesn't.
  # The problem was in the HTML, and it requires integration test to show(?)
  def test_update_species_list_add_unknown
    new_name = "Agaricus nova"
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    old_contribution = mary.contribution
    params = spl_params(spl)
    params[:list][:members] = new_name
    owner = spl.user.login
    assert_equal("mary", owner)
    login("mary")
    post(:edit_species_list, params: params)
    assert_edit_species_list

    spl.reload
    assert_equal(sp_count, spl.observations.size)

    params[:approved_names] = new_name
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)

    spl.reload
    assert_equal(sp_count + 1, spl.observations.size)
    assert_equal(old_contribution + v_nam + v_obs, mary.reload.contribution)
  end

  def test_update_species_list_text_add
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus"
    params[:species_list][:place_name] = "New Place, California, USA"
    params[:species_list][:title] = "New Title"
    params[:species_list][:notes] = "New notes."
    owner = spl.user.login
    assert_not_equal("rolf", owner)

    login("rolf")
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10, rolf.reload.contribution)
    assert(spl.reload.observations.size == sp_count)

    login(owner)
    post(:edit_species_list, params)
    # assert_redirected_to(controller: "location", action: "create_location")
    assert_redirected_to(%r{/location/create_location})
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert_equal("New Place, California, USA", spl.where)
    assert_equal("New Title", spl.title)
    assert_equal("New notes.", spl.notes)
  end

  def test_update_species_list_text_notifications
    spl = species_lists(:first_species_list)
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus\r\nAgaricus campestris"
    login("rolf")
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
  end

  def test_update_species_list_new_name
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_edit_species_list
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
  end

  def test_update_species_list_approved_new_name
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    params[:approved_names] = "New name"
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    # Creates "New", 'New name', observations/splentry/naming.
    assert_equal(10 + v_nam * 2 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
  end

  def test_update_species_list_multiple_match
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:amanita_baccata_arora)
    assert_not(spl.name_included(name))
    params = spl_params(spl)
    params[:list][:members] = name.text_name
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_edit_species_list
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert_not(spl.name_included(name))
  end

  def test_update_species_list_chosen_multiple_match
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:amanita_baccata_arora)
    assert_not(spl.name_included(name))
    params = spl_params(spl)
    params[:list][:members] = name.text_name
    params[:chosen_multiple_names] = { name.id.to_s => name.id.to_s }
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_deprecated
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    params = spl_params(spl)
    assert_not(spl.name_included(name))
    params[:list][:members] = name.text_name
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_edit_species_list
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert_not(spl.name_included(name))
  end

  def test_update_species_list_approved_deprecated
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    params = spl_params(spl)
    assert_not(spl.name_included(name))
    params[:list][:members] = name.text_name
    params[:approved_deprecated_names] = [name.id.to_s]
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_checklist_add
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_alpinus)
    params = spl_params(spl)
    assert_not(spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "1"
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_deprecated_checklist
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    params = spl_params(spl)
    assert_not(spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "1"
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_edit_species_list
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert_not(spl.name_included(name))
  end

  def test_update_species_list_approved_deprecated_checklist
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    params = spl_params(spl)
    assert_not(spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "1"
    params[:approved_deprecated_names] = [name.id.to_s]
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_approved_renamed_deprecated_checklist
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    approved_name = names(:lactarius_alpinus)
    params = spl_params(spl)
    assert_not(spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "1"
    params[:approved_deprecated_names] = [name.id.to_s]
    params[:chosen_approved_names] =
      { name.id.to_s => approved_name.id.to_s }
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert_not(spl.name_included(name))
    assert(spl.name_included(approved_name))
  end

  def test_update_species_list_approved_rename
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    approved_name = names(:lactarius_alpinus)
    params = spl_params(spl)
    assert_not(spl.name_included(name))
    assert_not(spl.name_included(approved_name))
    params[:list][:members] = name.text_name
    params[:approved_deprecated_names] = name.id.to_s
    params[:chosen_approved_names] =
      { name.id.to_s => approved_name.id.to_s }
    login(spl.user.login)
    post(:edit_species_list, params: params)
    assert_redirected_to(action: :show_species_list, id: spl.id)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert_not(spl.name_included(name))
    assert(spl.name_included(approved_name))
  end

  # ----------------------------
  #  Upload files.
  # ----------------------------

  def test_upload_species_list
    spl = species_lists(:first_species_list)
    params = {
      id: spl.id
    }
    requires_user(:upload_species_list, :show_species_list, params)
    assert_form_action(action: "upload_species_list", id: spl.id)
  end

  def test_read_species_list
    # TODO: Test read_species_list with a file larger than 13K to see if it
    # gets a TempFile or a StringIO.
    spl = species_lists(:first_species_list)
    assert_equal(0, spl.observations.length)
    filename = "#{::Rails.root}/test/species_lists/small_list.txt"
    file = File.new(filename)
    list_data = file.read.split(/\s*\n\s*/).reject(&:blank?).join("\r\n")
    file = Rack::Test::UploadedFile.new(filename, "text/plain")
    params = {
      "id" => spl.id,
      "species_list" => {
        "file" => file
      }
    }
    login("rolf", "testpassword")
    post(:upload_species_list, params)
    assert_edit_species_list
    assert_equal(10, rolf.reload.contribution)
    # Doesn't actually change list, just feeds it to edit_species_list
    assert_equal(list_data, @controller.instance_variable_get("@list_members"))
  end

  def test_read_species_list_two
    spl = species_lists(:first_species_list)
    assert_equal(0, spl.observations.length)
    filename = "#{::Rails.root}/test/species_lists/foray_notes.txt"
    file = File.new(filename)
    list_data = file.read.split(/\s*\n\s*/).reject(&:blank?).join("\r\n")
    file = Rack::Test::UploadedFile.new(filename, "text/plain")
    params = {
      "id" => spl.id,
      "species_list" => {
        "file" => file
      }
    }
    login("rolf", "testpassword")
    post(:upload_species_list, params)
    assert_edit_species_list
    assert_equal(10, rolf.reload.contribution)
    new_data = @controller.instance_variable_get("@list_members")
    new_data = new_data.split("\r\n").sort.join("\r\n")
    assert_equal(list_data, new_data)
  end

  # ----------------------------
  #  Name lister and reports.
  # ----------------------------

  def test_make_report
    now = Time.zone.now

    User.current = rolf
    tapinella = Name.create(
      author: "(Batsch) Šutara",
      text_name: "Tapinella atrotomentosa",
      search_name: "Tapinella atrotomentosa (Batsch) Šutara",
      sort_name: "Tapinella atrotomentosa (Batsch) Šutara",
      display_name: "**__Tapinella atrotomentosa__** (Batsch) Šutara",
      deprecated: false,
      rank: :Species
    )

    list = species_lists(:first_species_list)
    args = {
      place_name: "limbo",
      when: now,
      created_at: now,
      updated_at: now,
      user: rolf,
      specimen: false
    }
    list.construct_observation(tapinella, args)
    list.construct_observation(names(:fungi), args)
    list.construct_observation(names(:coprinus_comatus), args)
    list.construct_observation(names(:lactarius_alpigenes), args)
    list.save # just in case

    path = "#{::Rails.root}/test/reports"

    get(:make_report, params: { id: list.id, type: "csv" })
    assert_response_equal_file(["#{path}/test.csv", "ISO-8859-1"])

    get(:make_report, params: { id: list.id, type: "txt" })
    assert_response_equal_file("#{path}/test.txt")

    get(:make_report, params: { id: list.id, type: "rtf" })
    assert_response_equal_file("#{path}/test.rtf") do |x|
      x.sub(/\{\\createim\\yr.*\}/, "")
    end

    get(:make_report, params: { id: list.id, type: "bogus" })
    assert_response(:redirect)
    assert_flash_error
  end

  def test_print_labels
    spl = species_lists(:one_genus_three_species_list)
    query = Query.lookup_and_save(:Observation, :in_species_list,
                                  species_list: spl)
    query_params = @controller.query_params(query)
    get(:print_labels, id: spl.id)
    assert_redirected_to(query_params.merge(controller: "observer",
                                            action: "print_labels"))
  end

  def test_download
    spl = species_lists(:one_genus_three_species_list)
    query = Query.lookup_and_save(:Observation, :in_species_list,
                                  species_list: spl)

    get(:download, id: spl.id)

    args = { controller: "observer", action: "print_labels" }
    url = url_for(@controller.add_query_param(args, query))
    assert_select("form[action='#{url}']")

    url = url_for({ controller: "species_list", action: "make_report",
                    id: spl.id })
    assert_select("form[action='#{url}']")

    args = { controller: "observer", action: "download_observations" }
    url = url_for(@controller.add_query_param(args, query))
    assert_select("form[action='#{url}']")
  end

  def test_name_lister
    # This will have to be very rudimentary, since the vast majority of the
    # complexity is in Javascript.  Sigh.
    user = login("rolf")
    assert(user.is_successful_contributor?)
    get(:name_lister)

    params = {
      results: [
        "Amanita baccata|sensu Borealis*",
        "Coprinus comatus*",
        "Fungi*",
        "Lactarius alpigenes"
      ].join("\n")
    }

    post(:name_lister, params: params.merge(commit: :name_lister_submit_spl.l))
    ids = @controller.instance_variable_get("@names").map(&:id)
    assert_equal([names(:amanita_baccata_borealis).id,
                  names(:coprinus_comatus).id, names(:fungi).id,
                  names(:lactarius_alpigenes).id],
                 ids)
    assert_create_species_list

    path = "#{::Rails.root}/test/reports"

    post(:name_lister, params: params.merge(commit: :name_lister_submit_csv.l))
    assert_response_equal_file(["#{path}/test2.csv", "ISO-8859-1"])

    post(:name_lister, params: params.merge(commit: :name_lister_submit_txt.l))
    assert_response_equal_file("#{path}/test2.txt")

    post(:name_lister, params: params.merge(commit: :name_lister_submit_rtf.l))
    assert_response_equal_file("#{path}/test2.rtf") do |x|
      x.sub(/\{\\createim\\yr.*\}/, "")
    end

    post(:name_lister, params: { commit: "bogus" })
    assert_flash_error
    assert_template(:name_lister)
  end

  def test_name_resolution
    params = {
      species_list: {
        when: Time.zone.now,
        place_name: "Somewhere, California, USA",
        title: "title",
        notes: "notes"
      },
      member: { notes: Observation.no_notes },
      list: {}
    }
    @request.session[:user_id] = rolf.id

    params[:list][:members] = [
      "Fungi",
      "Agaricus sp",
      "Psalliota sp.",
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      "Chlorophyllum Author",
      "Lepiota sp Author"
    ].join("\n")
    params[:approved_names] = [
      "Psalliota sp.",
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      "Chlorophyllum Author",
      "Lepiota sp Author"
    ].join("\r\n")
    post(:create_species_list, params: params)
    assert_redirected_to(%r{/location/create_location})
    assert_equal(
      [
        "Fungi",
        "Agaricus",
        "Psalliota",
        "Chlorophyllum Author",
        "Lepiota Author",
        '"One"',
        '"Two"',
        '"Three"',
        'Agaricus "blah"'
      ].sort,
      assigns(:species_list).observations.map { |x| x.name.search_name }.sort
    )

    params[:list][:members] = [
      "Fungi",
      "Agaricus sp",
      "Psalliota sp.",
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      "Chlorophyllum Author",
      "Lepiota sp Author",
      "Lepiota sp. Author"
    ].join("\n")
    params[:approved_names] = [
      "Psalliota sp."
    ].join("\r\n")
    post(:create_species_list, params: params)
    assert_redirected_to(%r{/location/create_location})
    assert_equal(
      [
        "Fungi",
        "Agaricus",
        "Psalliota",
        "Chlorophyllum Author",
        "Lepiota Author",
        "Lepiota Author",
        '"One"',
        '"Two"',
        '"Three"',
        'Agaricus "blah"'
      ].sort,
      assigns(:species_list).observations.map { |x| x.name.search_name }.sort
    )
  end

  # ----------------------------
  #  Projects.
  # ----------------------------

  def test_project_checkboxes_in_create_species_list_form
    init_for_project_checkbox_tests

    login("mary")
    get(:create_species_list)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)

    login("dick")
    get(:create_species_list)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)

    login("rolf")
    get(:create_species_list)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    post(:create_species_list,
         params: { project: { "id_#{@proj1.id}" => "1" } })
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)

    # should have different default if recently create list attached to project
    obs = Observation.create!
    @proj1.add_observation(obs)
    get(:create_species_list)
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    post(:create_species_list,
         params: { project: { "id_#{@proj1.id}" => "0" } })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
  end

  def test_project_checkboxes_in_edit_species_list_form
    init_for_project_checkbox_tests

    login("rolf")
    get(:edit_species_list, params: { id: @spl1.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    get(:edit_species_list, params: { id: @spl2.id })
    assert_response(:redirect)

    login("mary")
    get(:edit_species_list, params: { id: @spl1.id })
    assert_response(:redirect)
    # Mary is allowed to remove her list from a project she's not on.
    get(:edit_species_list, params: { id: @spl2.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :checked)
    post(
      :edit_species_list,
      params: {
        id: @spl2.id,
        species_list: { title: "" }, # causes failure
        project: {
          "id_#{@proj1.id}" => "1",
          "id_#{@proj2.id}" => "0"
        }
      }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :unchecked)

    login("dick")
    get(:edit_species_list, params: { id: @spl1.id })
    assert_response(:redirect)
    get(:edit_species_list, params: { id: @spl2.id })
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :checked)
    @proj1.add_species_list(@spl2)
    # Disk is not allowed to remove Mary's list from a project he's not on.
    get(:edit_species_list, params: { id: @spl2.id })
    assert_project_checks(@proj1.id => :checked_but_disabled,
                          @proj2.id => :checked)
  end

  # ----------------------------
  #  Project Manager.
  # ----------------------------

  def test_manage_projects_permission
    list = species_lists(:unknown_species_list)

    # Requires login.
    get(:manage_projects, params: { id: list.id })
    assert_response(:redirect)

    # Must have permission to edit list.
    login("rolf")
    get(:manage_projects, params: { id: list.id })
    assert_response(:redirect)

    # Members of group that has list are good enough.
    login("dick")
    get(:manage_projects, params: { id: list.id })
    assert_response(:success)

    # Owner of list always can.
    login("mary")
    get(:manage_projects, id: list.id)
    assert_response(:success)
  end

  def test_manage_projects_list
    proj1 = projects(:eol_project)
    proj2 = projects(:bolete_project)
    list = species_lists(:unknown_species_list)

    login("dick")
    get(:manage_projects, params: { id: list.id })
    assert_checkbox_state("objects_list", :unchecked)
    assert_checkbox_state("objects_obs", :unchecked)
    assert_checkbox_state("objects_img", :unchecked)
    assert_checkbox_state("projects_#{proj1.id}", :no_field)
    assert_checkbox_state("projects_#{proj2.id}", :unchecked)

    login("mary")
    get(:manage_projects, params: { id: list.id })
    assert_checkbox_state("objects_list", :unchecked)
    assert_checkbox_state("objects_obs", :unchecked)
    assert_checkbox_state("objects_img", :unchecked)
    assert_checkbox_state("projects_#{proj1.id}", :unchecked)
    assert_checkbox_state("projects_#{proj2.id}", :unchecked)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "",
        commit: "bogus"
      }
    )
    assert_flash_error # bogus commit button
    assert_obj_list_equal([proj2], list.projects.reload)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "",
        commit: :ATTACH.l
      }
    )
    assert_flash_warning # no changes
    assert_obj_list_equal([proj2], list.projects.reload)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "1",
        commit: :ATTACH.l
      }
    )
    assert_flash_error # no permission
    assert_obj_list_equal([proj2], list.projects.reload)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "1",
        "projects_#{proj2.id}" => "",
        commit: :ATTACH.l
      }
    )
    assert_flash_success
    assert_obj_list_equal([proj1, proj2], list.projects.reload, :sort)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "1",
        "projects_#{proj2.id}" => "",
        commit: :ATTACH.l
      }
    )
    assert_flash_warning # already attached
    assert_obj_list_equal([proj1, proj2], list.projects.reload, :sort)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "",
        commit: :REMOVE.l
      }
    )
    assert_flash_warning # no changes
    assert_obj_list_equal([proj1, proj2], list.projects.reload, :sort)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "1",
        commit: :REMOVE.l
      }
    )
    assert_flash_success
    assert_obj_list_equal([proj1], list.projects.reload)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "1",
        commit: :REMOVE.l
      }
    )
    assert_flash_warning # no changes
    assert_obj_list_equal([proj1], list.projects.reload)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_list: "1",
        "projects_#{proj1.id}" => "1",
        "projects_#{proj2.id}" => "",
        commit: :REMOVE.l
      }
    )
    assert_flash_success
    assert_obj_list_equal([], list.projects.reload)
  end

  def test_manage_projects_obs_and_img
    proj1 = projects(:eol_project)
    proj2 = projects(:bolete_project)
    list = species_lists(:unknown_species_list)
    assert_equal(0, proj1.observations.length)
    assert_equal(0, proj1.images.length)
    assert_equal(1, proj2.observations.length)
    assert_equal(2, proj2.images.length)

    login("mary")
    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_obs: "1",
        objects_img: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "",
        commit: :ATTACH.l
      }
    )
    assert_flash_warning # no changes

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_obs: "1",
        objects_img: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "",
        commit: :REMOVE.l
      }
    )
    assert_flash_warning # no changes

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_obs: "1",
        objects_img: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "1",
        commit: :ATTACH.l
      }
    )
    assert_flash_error # no permission

    login("dick")
    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_obs: "1",
        objects_img: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "1",
        commit: :ATTACH.l
      }
    )
    assert_flash_warning # already done

    login("mary")
    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_obs: "1",
        objects_img: "1",
        "projects_#{proj1.id}" => "1",
        "projects_#{proj2.id}" => "",
        commit: :ATTACH.l
      }
    )
    assert_flash_success
    proj1.reload
    assert_equal(2, proj1.observations.length)
    assert_equal(2, proj1.images.length)

    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_obs: "1",
        objects_img: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "1",
        commit: :REMOVE.l
      }
    )
    assert_flash_success
    proj2.reload
    assert_equal(0, proj2.observations.length)
    assert_equal(0, proj2.images.length)

    login("dick")
    post(
      :manage_projects,
      params: {
        id: list.id,
        objects_obs: "1",
        objects_img: "1",
        "projects_#{proj1.id}" => "",
        "projects_#{proj2.id}" => "1",
        commit: :REMOVE.l
      }
    )
    assert_flash_warning # already done
  end

  def test_edit_species_list_member_parameters_initialization
    login("mary")
    spl = species_lists(:unknown_species_list)
    obs1, obs2 = spl.observations

    # If existing observations are all the same, use their values
    # as defaults for future observations.
    obs1.notes = obs2.notes = { Observation.other_notes_key => "test notes" }
    obs1.lat   = obs2.lat   = "12.3456"
    obs1.long  = obs2.long  = "-76.5432"
    obs1.alt   = obs2.alt   = "789"
    obs1.is_collection_location = false
    obs2.is_collection_location = false
    obs1.specimen = true
    obs2.specimen = true
    obs1.save!
    obs2.save!

    get(:edit_species_list, params: { id: spl.id })
    assert_edit_species_list
    assert_page_has_correct_notes_areas(
      klass: SpeciesList,
      expect_areas: { Observation.other_notes_key => "test notes" }
    )
    assert_input_value(:member_lat,   "12.3456")
    assert_input_value(:member_long,  "-76.5432")
    assert_input_value(:member_alt,   "789")
    assert_checkbox_state(:member_is_collection_location, false)
    assert_checkbox_state(:member_specimen, true)

    # When existing observations have differing values, it should use
    # standard defaults from create_observation, instead.
    obs1.notes = "different notes"
    obs1.lat   = "-12.3456"
    obs1.long  = "76.5432"
    obs1.alt   = "123"
    obs1.is_collection_location = true
    obs1.specimen = false
    obs1.save!

    get(:edit_species_list, params: { id: spl.id })
    assert_edit_species_list
    assert_page_has_correct_notes_areas(
      klass: SpeciesList,
      expect_areas: { Observation.other_notes_key => "" }
    )
    assert_input_value(:member_lat, "")
    assert_input_value(:member_long, "")
    assert_input_value(:member_alt, "")
    assert_checkbox_state(:member_is_collection_location, true)
    assert_checkbox_state(:member_specimen, false)
  end

  def test_add_remove_observations
    query = Query.lookup(:Observation, :all, users: users(:mary))
    assert(query.num_results > 1)
    params = @controller.query_params(query)

    requires_login(:add_remove_observations)
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/list_species_lists})
    assert_flash_error

    get(:add_remove_observations, params: params)
    assert_response(:success)
    assert_input_value(:species_list, "")

    get(:add_remove_observations, params: params.merge(species_list: "blah"))
    assert_response(:success)
    assert_input_value(:species_list, "blah")
  end

  def test_post_add_remove_observations
    query = Query.lookup(:Observation, :all, users: users(:mary))
    assert(query.num_results > 1)
    params = @controller.query_params(query)

    spl = species_lists(:unknown_species_list)
    old_count = spl.observations.size
    new_count = (spl.observations + query.results).uniq.count

    # make sure there are already some observations in list
    assert(old_count > 1)
    # make sure we are actually trying to add some observations!
    assert(new_count > old_count)
    # make sure some of the query results are already in there
    assert(query.results & spl.observations != [])

    post_requires_login(:post_add_remove_observations)
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/add_remove_observations})
    assert_flash_error
    assert_equal(old_count, spl.reload.observations.size)

    post(:post_add_remove_observations, params: params)
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/add_remove_observations})
    assert_flash_error
    assert_equal(old_count, spl.reload.observations.size)

    post(:post_add_remove_observations,
         params: params.merge(species_list: "blah"))
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/add_remove_observations})
    assert_flash_error
    assert_equal(old_count, spl.reload.observations.size)

    post(:post_add_remove_observations,
         params: { species_list: spl.title })
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/show_species_list})
    assert_flash_error
    assert_equal(old_count, spl.reload.observations.size)

    post(:post_add_remove_observations,
         params: params.merge(species_list: spl.title))
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/show_species_list})
    assert_flash_error
    assert_equal(old_count, spl.reload.observations.size)

    post(:post_add_remove_observations,
         params: params.merge(commit: "bogus", species_list: spl.title))
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/show_species_list})
    assert_flash_error
    assert_equal(old_count, spl.reload.observations.size)

    post(:post_add_remove_observations,
         params: params.merge(commit: :ADD.l, species_list: spl.title))
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/show_species_list})
    assert_flash_error
    assert_equal(old_count, spl.reload.observations.size)

    login("mary")
    post(:post_add_remove_observations,
         params: params.merge(commit: :ADD.l, species_list: spl.title))
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/show_species_list})
    assert_flash_success
    assert_equal(new_count, spl.reload.observations.size)

    post(:post_add_remove_observations,
         params: params.merge(commit: :REMOVE.l, species_list: spl.id.to_s))
    assert_response(:redirect)
    assert_redirected_to(%r{/species_list/show_species_list})
    assert_flash_success
    assert_equal(0, spl.reload.observations.size)
  end

  def test_post_add_remove_double_observations
    spl = species_lists(:unknown_species_list)
    old_obs_list = SpeciesList.connection.select_values(%(
      SELECT observation_id FROM observations_species_lists
      WHERE species_list_id = #{spl.id}
      ORDER BY observation_id ASC
    ))
    dup_obs = spl.observations.first
    new_obs = (Observation.all - spl.observations).first
    ids = [dup_obs.id, new_obs.id]
    query = Query.lookup(:Observation, :in_set, ids: ids)
    params = @controller.query_params(query).merge(
      commit: :ADD.l,
      species_list: spl.title
    )
    login(spl.user.login)
    post(:post_add_remove_observations, params: params)
    assert_response(:redirect)
    assert_flash_success
    new_obs_list = SpeciesList.connection.select_values(%(
      SELECT observation_id FROM observations_species_lists
      WHERE species_list_id = #{spl.id}
      ORDER BY observation_id ASC
    ))
    assert_equal(new_obs_list.length, old_obs_list.length + 1)
    assert_equal((new_obs_list - old_obs_list).first, new_obs.id)
  end

  def test_clear_checklist
    spl = species_lists(:one_genus_three_species_list)
    assert_equal("mary", spl.user.login)
    assert_operator(spl.observations.count, :>, 1)

    get(:clear_species_list)
    assert_no_flash
    assert_not_equal(0, spl.reload.observations.count)

    get(:clear_species_list, id: spl.id)
    assert_no_flash
    assert_not_equal(0, spl.reload.observations.count)

    login("rolf")
    get(:clear_species_list, id: spl.id)
    assert_flash_error
    assert_not_equal(0, spl.reload.observations.count)

    login("mary")
    expected_score = mary.contribution - spl.observations.count
    get(:clear_species_list, id: spl.id)
    assert_flash_success
    assert_equal(0, spl.reload.observations.count)
    assert_equal(expected_score, mary.reload.contribution)
  end

  # ------------------------------------------
  #  Checklists in create/edit_species_list.
  # ------------------------------------------

  def test_set_source
    login("rolf")
    spl1 = species_lists(:unknown_species_list)
    spl2 = species_lists(:one_genus_three_species_list)
    query1 = Query.lookup_and_save(:Observation, :in_species_list,
                                   species_list: spl1.id, by: :name)
    query2 = Query.lookup_and_save(:Observation, :in_species_list,
                                   species_list: spl2.id, by: :name)

    # make sure the "Set Source" link is on the page somewhere
    get(:show_species_list, id: spl1.id)
    link_args = { controller: :species_list, action: :show_species_list,
                  id: spl1.id, set_source: 1 }
    assert_link_in_html(:species_list_show_set_source.t, link_args)

    # make sure clicking on "Set Source" changes the session
    @request.session[:checklist_source] = nil
    get(:show_species_list, id: spl1.id, set_source: 1)
    assert_equal(query1.id, @controller.session[:checklist_source])

    # make sure showing another list doesn't override the source
    @request.session[:checklist_source] = query1.id
    get(:show_species_list, id: spl2.id)
    # (Non-integration tests apparently don't actually let the controller
    # change the @request.session.  Instead it gives the controller a blank
    # session to record any changes the controller tries to make.)
    assert_nil(@controller.session[:checklist_source])

    # make sure no checklist appears if no source set
    @request.session[:checklist_source] = nil
    get(:create_species_list)
    assert_select("div#checklist_data", count: 0)

    @request.session[:checklist_source] = nil
    get(:edit_species_list, id: spl2.id)
    assert_select("div#checklist_data", count: 0)

    # make sure the source observations appear if source set
    @request.session[:checklist_source] = query2.id
    get(:create_species_list)
    assert_select("div#checklist_data")
    name1 = spl2.observations.first.name.id
    assert_select("input[name='checklist_data[#{name1}]']")

    login(spl1.user.login)
    @request.session[:checklist_source] = query2.id
    get(:edit_species_list, id: spl1.id)
    assert_select("div#checklist_data")
    name2 = spl2.observations.last.name.id
    assert_select("input[name='checklist_data[#{name2}]']")
  end
end
