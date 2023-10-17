# frozen_string_literal: true

require("test_helper")

class SpeciesListsControllerTest < FunctionalTestCase
  # NOTE: I don't know how to grab the DEFAULT from the fixture set and
  #   User.find(ActiveRecord::FixtureSet.identify(:rolf)).contribution
  # blows up in CI with
  # Couldn't find User with 'id'=241228755 (ActiveRecord::RecordNotFound)
  # See https://github.com/MushroomObserver/mushroom-observer/actions/runs/3863461654/jobs/6585724583
  # JDC 2023-01-07
  BASE_CONTRIBUTION = 10

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

  def assert_create_species_list
    assert_template("new")
    assert_template("shared/_form_list_feedback")
    assert_template("shared/_textilize_help")
    assert_template("species_lists/_form")
  end

  def assert_edit_species_list
    assert_template("edit")
    assert_template("shared/_form_list_feedback")
    assert_template("shared/_textilize_help")
    assert_template("species_lists/_form")
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
    assert_obj_arrays_equal([], @spl1.projects)
    assert_obj_arrays_equal([@proj2], @spl2.projects)
    assert_obj_arrays_equal([rolf, mary, katrina], @proj1.user_group.users)
    assert_obj_arrays_equal([dick], @proj2.user_group.users)
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

  def test_index
    login
    get(:index)

    assert_displayed_title("Species Lists by Date")
    assert_select(
      "#content a:match('href', ?)", %r{^#{species_lists_path}/\d+},
      { count: SpeciesList.count },
      "Wrong number of results"
    )
  end

  def test_index_sorted_by_user
    by = "user"

    login
    get(:index, params: { by: by })

    assert_displayed_title("Species Lists by #{by.capitalize}")
  end

  def test_index_sorted_by_time_modifed
    by = "modified"

    login
    get(:index, params: { by: by })

    assert_response(:success)
    assert_displayed_title("Species Lists by Time Last Modified")
  end

  def test_index_sorted_by_date_created
    by = "created"

    login
    get(:index, params: { by: by })

    assert_response(:success)
    assert_displayed_title("Species Lists by Date Created")
  end

  def test_index_sorted_by_title
    by = "title"

    login
    get(:index, params: { by: by })

    assert_displayed_title("Species Lists by Title")
  end

  def test_index_with_id_and_sorted_by_title
    list = species_lists(:unknown_species_list)
    by = "title"

    login
    get(:index, params: { id: list.id, by: by })

    assert_displayed_title("Species Lists by Title")
  end

  def test_index_with_id
    list = species_lists(:unknown_species_list)

    login
    get(:index, params: { id: list.id })

    assert_displayed_title("Species Lists by Date")
  end

  def test_index_pattern_multiple_hits
    pattern = "query"

    login
    get(:index, params: { pattern: pattern })

    assert_response(:success)
    assert_displayed_title("Species Lists Matching ‘#{pattern}’")
    assert_select(
      "#content a:match('href', ?)", %r{^#{species_lists_path}/\d+},
      { count: SpeciesList.where(SpeciesList[:title] =~ pattern).count },
      "Wrong number of results"
    )
  end

  def test_index_pattern_id
    spl = species_lists(:unknown_species_list)

    login
    get(:index, params: { pattern: spl.id })

    assert_redirected_to(species_list_path(spl.id))
  end

  def test_index_pattern_one_hit
    pattern = "mysteries"

    login
    get(:index, params: { pattern: pattern })

    assert_response(:redirect)
    assert_match(
      species_list_path(species_lists(:unknown_species_list)),
      redirect_to_url,
      "Wrong page"
    )
  end

  def test_index_by_user
    user = rolf

    login
    get(:index, params: { by_user: user })

    assert_displayed_title("Species Lists created by #{user.name}")
  end

  def test_index_by_user_with_no_species_lists
    user = users(:zero_user)

    login
    get(:index, params: { by_user: user })

    assert_response(:success)
    assert_displayed_title("")
  end

  def test_index_for_user_who_does_not_exist
    user = observations(:minimal_unknown_obs)

    login
    get(:index, params: { by_user: user })

    assert_response(:redirect)
    assert_redirected_to(species_lists_path)
    assert_displayed_title("")
    assert_flash_text(
      :runtime_object_not_found.l(type: :user, id: user.id)
    )
  end

  def test_index_for_project
    project = projects(:bolete_project)

    login
    get(:index, params: { for_project: project.id })

    assert_displayed_title("Species Lists attached to #{project.title}")
  end

  def test_index_for_project_with_no_lists
    project = projects(:empty_project)

    login
    get(:index, params: { for_project: project.id })

    assert_response(:success)
    assert_displayed_title("")
    assert_flash_text(:runtime_no_matches.l(types: :species_lists))
  end

  def test_index_for_project_that_does_not_exist
    project = observations(:minimal_unknown_obs)

    login
    get(:index, params: { for_project: project.id })

    assert_response(:redirect)
    assert_redirected_to(projects_path)
    assert_flash_text(
      :runtime_object_not_found.l(type: :project, id: project.id)
    )
  end

  def test_show_species_list_non_owner_logged_in
    list = species_lists(:unknown_species_list)
    observations = list.observations
    assert(observations.any?,
           "Need SpeciesList fixture that has >= 1 Observation")
    assert_not_equal(rolf, list.user)

    login(rolf.login)
    get(:show, params: { id: list.id })

    assert_template(:show)
    assert_template("comments/_comments_for_object")
    assert_select(
      "form:match('action', ?)",
      %r{/observations/\d+/species_lists/#{list.id}/remove},
      { count: 0 },
      "Non owner should not get buttons to remove Observations from List"
    )
  end

  def test_show_species_list_owner_logged_in
    list = species_lists(:unknown_species_list)
    observations = list.observations
    assert(observations.any?,
           "Need SpeciesList fixture that has >= 1 Observation")

    login(list.user.login)
    get(:show, params: { id: list.id })

    assert_template(:show)
    assert_template("comments/_comments_for_object")
    assert_select(
      "form:match('action', ?)",
      %r{/observations/\d+/species_lists/#{list.id}/remove},
      { count: observations.size },
      "Species List owner should get 1 Remove button per Observation"
    )
  end

  def test_show_species_lists_attached_to_projects
    login
    proj1 = projects(:eol_project)
    proj2 = projects(:bolete_project)
    spl = species_lists(:first_species_list)
    assert_obj_arrays_equal([], spl.projects)

    get(:show, params: { id: spl.id })
    assert_no_match(proj1.title.t, @response.body)
    assert_no_match(proj2.title.t, @response.body)

    proj1.add_species_list(spl)
    get(:show, params: { id: spl.id })
    assert_match(proj1.title.t, @response.body)
    assert_no_match(proj2.title.t, @response.body)

    proj2.add_species_list(spl)
    get(:show, params: { id: spl.id })
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
    get(:show, params: { id: spl.id })
    assert_select("a[href*=?]", edit_species_list_path(spl.id), count: 0)
    assert_select("form[action=?]", species_list_path(spl.id), count: 0)
    get(:edit, params: { id: spl.id })
    assert_response(:redirect)
    delete(:destroy, params: { id: spl.id })
    assert_flash_error

    login("mary")
    get(:show, params: { id: spl.id })
    assert_select("a[href*=?]", edit_species_list_path(spl.id), minimum: 1)
    assert_select("form[action=?]", species_list_path(spl.id), minimum: 1)
    get(:edit, params: { id: spl.id })
    assert_response(:success)

    login("dick")
    get(:show, params: { id: spl.id })
    assert_select("a[href*=?]", edit_species_list_path(spl.id), minimum: 1)
    assert_select("form[action=?]", species_list_path(spl.id), minimum: 1)
    get(:edit, params: { id: spl.id })
    assert_response(:success)
    delete(:destroy, params: { id: spl.id })
    assert_flash_success
  end

  def test_show_flow
    login
    query = Query.lookup_and_save(:SpeciesList, :all, by: "reverse_user")
    query_params = @controller.query_params(query)
    get(:index, params: query_params)
    assert_template(:index)

    get(:show, params: query_params.merge(id: query.result_ids[0], flow: :next))
    assert_redirected_to(query_params.merge(action: :show,
                                            id: query.result_ids[1]))

    get(:show, params: query_params.merge(id: query.result_ids[1], flow: :prev))
    assert_redirected_to(query_params.merge(action: :show,
                                            id: query.result_ids[0]))
  end

  def test_destroy_species_list
    login
    spl = species_lists(:first_species_list)
    assert(spl)
    id = spl.id
    params = { id: id.to_s }
    assert_equal("rolf", spl.user.login)
    requires_user(:destroy, { action: :show }, params)
    assert_redirected_to(action: :index)
    assert_raises(ActiveRecord::RecordNotFound) do
      SpeciesList.find(id)
    end
  end

  # ----------------------------
  #  Create lists.
  # ----------------------------

  def test_create_species_list
    requires_login(:new)
    assert_form_action(action: :create)
  end

  def test_create_species_list_member_notes_areas
    # Prove that only member_notes textarea is Other
    # for user without notes template
    user = users(:rolf)
    login(user.login)
    get(:new)
    assert_page_has_correct_notes_areas(
      klass: SpeciesList,
      expect_areas: { Observation.other_notes_key => "" }
    )

    # Prove that member_notes textareas are those for template plus Other
    # for user with notes template
    user = users(:notes_templater)
    login(user.login)
    get(:new)
    assert_page_has_correct_notes_areas(
      klass: SpeciesList,
      expect_areas: { Cap: "", Nearby_trees: "", odor: "",
                      Observation.other_notes_key => "" }
    )
  end

  def test_unsuccessful_create_species_list
    user = login("spamspamspam")
    assert_false(user.successful_contributor?)
    get(:new)
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
        title: "  #{list_title.sub(/ /, "  ")}  ",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        notes: "List Notes"
      }
    }
    post_requires_login(:create, params)
    spl = SpeciesList.last
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_spl + v_obs, rolf.reload.contribution)
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
    post_requires_login(:create, params)
    spl = SpeciesList.last
    assert_redirected_to(species_list_path(spl.id))
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
    post(:create, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_spl + v_obs, rolf.reload.contribution)
    assert_not_nil(spl)
    assert(spl.name_included(agaricus))
  end

  def test_construct_species_list_new_family
    list_title = "List Title"
    rank = "Family"
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
    post(:create, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(species_list_path(spl.id))
    # Creates Lecideaceae, spl, and obs/naming/splentry.
    assert_equal(BASE_CONTRIBUTION + v_nam + v_spl + v_obs,
                 rolf.reload.contribution)
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
    post(:create, params: params)
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
    post(:create, params: params)
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
    post(:create, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(species_list_path(spl.id))
    # Creating L. rubidus (and spl and obs/splentry/naming).
    assert_equal(BASE_CONTRIBUTION + v_nam + v_spl + v_obs,
                 rolf.reload.contribution)
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
    post(:create, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(species_list_path(spl.id))
    # Creates Lecideaceae, spl, obs/naming/splentry.
    assert_equal(BASE_CONTRIBUTION + v_nam + v_spl + v_obs,
                 rolf.reload.contribution)
    assert_not_nil(spl)
    new_name = Name.find_by(text_name: new_name_str)
    assert_not_nil(new_name)
    assert_equal("Family", new_name.rank)
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
    post(:create, params: params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(species_list_path(spl.id))
    # Creates "New" and "New name", spl, and five obs/naming/splentries.
    assert_equal(BASE_CONTRIBUTION + v_nam * 2 + v_spl + v_obs * 5,
                 rolf.reload.contribution)
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
    post(:create, params: params)
    assert_create_species_list
    assert_equal(10, rolf.reload.contribution)
    assert_equal("Warnerbros bugs-bunny",
                 @controller.instance_variable_get(:@list_members))
    assert_equal([], @controller.instance_variable_get(:@new_names))
    assert_equal([bugs_names.first],
                 @controller.instance_variable_get(:@multiple_names))
    assert_equal([], @controller.instance_variable_get(:@deprecated_names))

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
    post(:create, params: params)
    spl = SpeciesList.last

    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_spl + v_obs, rolf.reload.contribution)
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
    post_requires_login(:create, params)
    spl = SpeciesList.find_by(title: list_title)

    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_spl + v_obs, rolf.reload.contribution)
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
        "when(3i)" => "14"
      }
    }
    login("rolf")
    post(:create, params: params)
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
    params = { id: spl.id }
    assert_equal("rolf", spl.user.login)
    requires_user(:edit, { action: :show }, params)
    assert_edit_species_list
    assert_form_action({ action: :update, id: spl.id,
                         approved_where: "Burbank, California, USA" })
  end

  def test_update_species_list_nochange
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    put_requires_user(:update, { action: :show }, params,
                      spl.user.login)
    assert_redirected_to(species_list_path(spl.id))
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(10, rolf.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)

    login(owner)
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_obs * 2, spl.user.reload.contribution)
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
    put(:update, params: params)
    assert_edit_species_list

    spl.reload
    assert_equal(sp_count, spl.observations.size)

    params[:approved_names] = new_name
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))

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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(10, rolf.reload.contribution)
    assert(spl.reload.observations.size == sp_count)

    login(owner)
    put(:update, params: params)
    assert_redirected_to(/#{new_location_path}/)
    assert_equal(BASE_CONTRIBUTION + v_obs, spl.user.reload.contribution)
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
  end

  def test_update_species_list_new_name
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    login(spl.user.login)
    put(:update, params: params)
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_nam * 2 + v_obs,
                 spl.user.reload.contribution)
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
    put(:update, params: params)
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_obs, spl.user.reload.contribution)
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
    put(:update, params: params)
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_obs, spl.user.reload.contribution)
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_obs, spl.user.reload.contribution)
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
    put(:update, params: params)
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_obs, spl.user.reload.contribution)
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_obs, spl.user.reload.contribution)
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
    put(:update, params: params)
    assert_redirected_to(species_list_path(spl.id))
    assert_equal(BASE_CONTRIBUTION + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert_not(spl.name_included(name))
    assert(spl.name_included(approved_name))
  end

  # ----------------------------
  #  Name lister and reports.
  # ----------------------------

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
    post(:create, params: params)
    assert_redirected_to(/#{new_location_path}/)
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
    post(:create, params: params)
    assert_redirected_to(/#{new_location_path}/)
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
    get(:new)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)

    login("dick")
    get(:new)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)

    login("rolf")
    get(:new)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    post(:create,
         params: { project: { "id_#{@proj1.id}" => "1" } })
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)

    # should have different default if recently create list attached to project
    obs = Observation.create!
    @proj1.add_observation(obs)
    get(:new)
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    post(:create,
         params: { project: { "id_#{@proj1.id}" => "0" } })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
  end

  def test_project_checkboxes_in_edit_species_list_form
    init_for_project_checkbox_tests

    login("rolf")
    get(:edit, params: { id: @spl1.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    get(:edit, params: { id: @spl2.id })
    assert_response(:redirect)

    login("mary")
    get(:edit, params: { id: @spl1.id })
    assert_response(:redirect)
    # Mary is allowed to remove her list from a project she's not on.
    get(:edit, params: { id: @spl2.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :checked)
    put(
      :update,
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
    get(:edit, params: { id: @spl1.id })
    assert_response(:redirect)
    get(:edit, params: { id: @spl2.id })
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :checked)
    @proj1.add_species_list(@spl2)
    # Disk is not allowed to remove Mary's list from a project he's not on.
    get(:edit, params: { id: @spl2.id })
    assert_project_checks(@proj1.id => :checked_but_disabled,
                          @proj2.id => :checked)
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

    get(:edit, params: { id: spl.id })
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

    get(:edit, params: { id: spl.id })
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

  def test_clear_checklist
    spl = species_lists(:one_genus_three_species_list)
    assert_equal("mary", spl.user.login)
    assert_operator(spl.observations.count, :>, 1)

    put(:clear, params: { id: spl.id })
    assert_no_flash
    assert_not_equal(0, spl.reload.observations.count)

    login("rolf")
    put(:clear, params: { id: spl.id })
    assert_flash_error
    assert_not_equal(0, spl.reload.observations.count)

    login("mary")
    expected_score = mary.contribution - spl.observations.count
    put(:clear, params: { id: spl.id })
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
    get(:show, params: { id: spl1.id })
    assert_link_in_html(:species_list_show_set_source.t,
                        species_list_path(spl1.id, set_source: 1))

    # make sure clicking on "Set Source" changes the session
    @request.session[:checklist_source] = nil
    get(:show, params: { id: spl1.id, set_source: 1 })
    assert_equal(query1.id, @controller.session[:checklist_source])

    # make sure showing another list doesn't override the source
    @request.session[:checklist_source] = query1.id
    get(:show, params: { id: spl2.id })
    # (Non-integration tests apparently don't actually let the controller
    # change the @request.session.  Instead it gives the controller a blank
    # session to record any changes the controller tries to make.)
    assert_nil(@controller.session[:checklist_source])

    # make sure no checklist appears if no source set
    @request.session[:checklist_source] = nil
    get(:new)
    assert_select("#checklist_data", count: 0)

    @request.session[:checklist_source] = nil
    get(:edit, params: { id: spl2.id })
    assert_select("#checklist_data", count: 0)

    # make sure the source observations appear if source set
    @request.session[:checklist_source] = query2.id
    get(:new)
    assert_select("#checklist_data")
    name1 = spl2.observations.first.name.id
    assert_select("input[name='checklist_data[#{name1}]']")

    login(spl1.user.login)
    @request.session[:checklist_source] = query2.id
    get(:edit, params: { id: spl1.id })
    assert_select("#checklist_data")
    name2 = spl2.observations.last.name.id
    assert_select("input[name='checklist_data[#{name2}]']")
  end
end
