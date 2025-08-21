# frozen_string_literal: true

require("test_helper")

class SpeciesListsControllerTest < FunctionalTestCase
  # NOTE: I don't know how to grab the DEFAULT from the fixture set and
  #   User.find(ActiveRecord::FixtureSet.identify(:rolf)).contribution
  # blows up in CI with
  # Couldn't find User with 'id'=241228755 (ActiveRecord::RecordNotFound)
  # See https://github.com/MushroomObserver/mushroom-observer/actions/runs/3863461654/jobs/6585724583
  # JDC 2023-01-07
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
    assert_template("species_lists/_form")
  end

  def assert_edit_species_list
    assert_template("edit")
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
    assert_obj_arrays_equal([mary, dick], @proj2.user_group.users)
  end

  def obs_params(obs, vote)
    {
      when_str: obs.when_str,
      place_name: obs.place_name,
      notes: obs.notes,
      lat: obs.lat,
      lng: obs.lng,
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

    assert_page_title(:SPECIES_LISTS.l)
    assert_select(
      "#content a:match('href', ?)", %r{^#{species_lists_path}/\d+},
      { count: SpeciesList.count },
      "Wrong number of results"
    )
  end

  # These tests for titles were never returning the actual sorted results!
  # The params "created" and "modified" do not even work.
  # The incorrect query (often blank) simply got the "right" title.
  def test_index_sorted_by_user
    login

    by = "user"
    get(:index, params: { by: by })

    assert_equal(SpeciesList.order_by(:user).map(&:user_id),
                 assigns(:objects).map(&:user_id))
    assert_page_title(:SPECIES_LISTS.l)
    assert_sorted_by(by)
  end

  def test_index_with_non_default_sort
    check_index_sorting
  end

  def test_index_with_id_and_sorted_by_title
    list = species_lists(:unknown_species_list)
    by = "title"

    login
    get(:index, params: { id: list.id, by: by })

    assert_page_title(:SPECIES_LISTS.l)
    assert_sorted_by(by)
  end

  def test_index_with_id
    list = species_lists(:unknown_species_list)

    login
    get(:index, params: { id: list.id })

    assert_page_title(:SPECIES_LISTS.l)
    assert_sorted_by("date")
  end

  def test_index_pattern_multiple_hits
    pattern = "query"

    login
    get(:index, params: { pattern: pattern })

    assert_response(:success)
    assert_page_title(:SPECIES_LISTS.l)
    assert_displayed_filters("#{:query_pattern.l}: #{pattern}")
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

    assert_page_title(:SPECIES_LISTS.l)
    assert_displayed_filters("#{:query_by_users.l}: #{user.name}")
  end

  def test_index_by_user_with_no_species_lists
    user = users(:zero_user)

    login
    get(:index, params: { by_user: user })

    assert_response(:success)
    assert_page_title(:SPECIES_LISTS.l)
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
    get(:index, params: { project: project.id })

    # there's no banner for this project
    assert_page_title(:SPECIES_LISTS.l)
    assert_match(project.species_lists.first.title, @response.body)
  end

  def test_index_for_project_with_no_lists
    project = projects(:empty_project)

    login
    get(:index, params: { project: project.id })

    assert_response(:success)
    assert_page_title(:SPECIES_LISTS.l)
    assert_flash_text(:runtime_no_matches.l(types: :species_lists))
  end

  def test_index_for_project_that_does_not_exist
    project = observations(:minimal_unknown_obs)

    login
    get(:index, params: { project: project.id })

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
      "Observation List owner should get 1 Remove button per Observation"
    )
  end

  def test_show_species_list_for_project
    login
    spl = species_lists(:reused_list)
    project = spl.projects[0]

    get(:show, params: { id: spl.id, project: project.id })
    assert_match(project.title, @response.body)
    assert_select("h1#title", /#{spl.title}/,
                  "H1 title element should exist and contain content")
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
    assert_equal([mary.id, dick.id],
                 proj.user_group.users.map(&:id)) # dick is only project member

    login("rolf")
    get(:show, params: { id: spl.id })
    assert_select("a[href*=?]", edit_species_list_path(spl.id), count: 0)
    assert_select("form[action=?]", add_dispatch_path, count: 1)
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
    query = Query.lookup_and_save(:SpeciesList, order_by: "reverse_user")
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

  def test_unsuccessful_create_species_list
    user = login("spamspamspam")
    assert_false(user.successful_contributor?)
    get(:new)
    assert_response(:redirect)
  end

  def test_clone_species_list
    login
    spl = species_lists(:unknown_species_list)
    get(:new, params: { clone: spl.id })
    assert_response(:success)
    assert_match(spl.where, @response.body)
  end

  # Test constructing species_lists in various ways.
  def test_construct_species_list
    list_title = "List Title"
    contrib = rolf.contribution + SPECIES_LIST_SCORE
    params = {
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
    assert_equal(contrib, rolf.reload.contribution)
    assert_not_nil(spl)
    assert_equal(list_title, spl.title)
  end

  def test_construct_species_list_without_location
    list_title = "List Title"
    params = {
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

  def test_create_with_projects
    params = {
      species_list: {
        place_name: "Earth",
        title: "List with Project",
        "when(1i)" => "2025",
        "when(2i)" => "3",
        "when(3i)" => "14"
      },
      project: rolf.projects_member.each_with_object({}) do |obj, result|
        result["id_#{obj.id}"] = "1"
      end
    }
    login("rolf")
    post(:create, params: params)
    spl = SpeciesList.last
    assert(spl.projects.any?)
  end

  # -----------------------------------------------
  #  Test changing species_lists in various ways.
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

  def test_edit_with_projects
    spl = species_lists(:reused_list)
    count = spl.projects.count
    login(spl.user.login)
    params = { id: spl.id,
               project: spl.projects.each_with_object({}) do |obj, result|
                 result["id_#{obj.id}"] = "0"
               end,
               species_list: { title: spl.title } }
    put(:update, params:)
    spl.reload
    assert(spl.projects.count < count)
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

  # ----------------------------
  #  Projects.
  # ----------------------------

  def test_project_checkboxes_in_create_species_list_form
    init_for_project_checkbox_tests

    login("mary")
    get(:new)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :unchecked)
    post(:create,
         params: { project: { "id_#{@proj1.id}" => "1" } })
    assert_project_checks(@proj1.id => :checked, @proj2.id => :unchecked)

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
    obs = Observation.create!(user: rolf)
    @proj1.add_observation(obs)
    get(:new)
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
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

  def test_clear
    spl = species_lists(:unknown_species_list)
    login(spl.user.login)
    assert(spl.observations.any?)
    put(:clear, params: { id: spl.id })
    assert(spl.observations.none?)
  end

  def test_clear_not_owner
    spl = species_lists(:unknown_species_list)
    login("rolf")
    initial_count = spl.observations.count
    put(:clear, params: { id: spl.id })
    assert(spl.observations.count == initial_count)
  end
end
