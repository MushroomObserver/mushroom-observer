# frozen_string_literal: true

require("test_helper")

class OccurrencesControllerTest < FunctionalTestCase
  def setup
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    # Clear any occurrence from field slip fixture
    @obs1.update_column(:occurrence_id, nil)
  end

  # ---------- new action ----------

  def test_new_requires_login
    requires_login(:new, observation_id: @obs1.id)
    assert_response(:success)
  end

  def test_new_with_missing_observation
    login("rolf")
    get(:new, params: { observation_id: -1 })
    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_new_with_no_observation_id
    login("rolf")
    get(:new, params: {})
    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_new_redirects_if_occurrence_exists
    login("rolf")
    occ = Occurrence.create!(user: rolf,
                             primary_observation: @obs1)
    @obs1.update!(occurrence: occ)
    @obs2.update!(occurrence: occ)

    get(:new, params: { observation_id: @obs1.id })
    assert_redirected_to(permanent_observation_path(@obs1.id))
    assert_flash_warning
  end

  # ---------- create action ----------

  def test_create_requires_login
    post_requires_login(
      :create,
      observation_ids: [@obs1.id, @obs2.id],
      occurrence: { observation_id: @obs1.id,
                    primary_observation_id: @obs1.id }
    )
  end

  def test_create_success
    login("rolf")
    obs3 = observations(:detailed_unknown_obs) # same location as obs1
    params = create_params(@obs1, [@obs1, obs3])
    params[:project_resolution] = "add_all"
    assert_difference("Occurrence.count", 1) do
      post(:create, params: params)
    end
    occ = Occurrence.last
    assert_equal(@obs1, occ.primary_observation)
    assert_equal(2, occ.observations.count)
    assert_redirected_to(occurrence_path(occ))
    assert_flash_success
  end

  def test_create_with_different_primary
    login("rolf")
    post(:create, params: create_params(@obs1, [@obs1, @obs2],
                                        primary: @obs2))
    occ = Occurrence.last
    assert_equal(@obs2, occ.primary_observation)
  end

  def test_create_needs_at_least_two
    login("rolf")
    assert_no_difference("Occurrence.count") do
      post(:create, params: create_params(@obs1, [@obs1]))
    end
    assert_redirected_to(
      new_occurrence_path(observation_id: @obs1.id)
    )
    assert_flash_error
  end

  def test_create_with_missing_source_observation
    login("rolf")
    post(:create, params: {
           observation_ids: [-1, @obs2.id],
           occurrence: { observation_id: -1,
                         primary_observation_id: -1 }
         })
    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_create_with_field_slip_conflict
    login("rolf")
    fs1 = field_slips(:field_slip_one)
    fs2 = field_slips(:field_slip_two)
    @obs1.update!(field_slip: fs1)
    @obs2.update!(field_slip: fs2)

    assert_no_difference("Occurrence.count") do
      post(:create, params: create_params(@obs1, [@obs1, @obs2]))
    end
    assert_redirected_to(
      new_occurrence_path(observation_id: @obs1.id)
    )
    assert_flash_error
  end

  # Simulate actual browser round-trip: render form, extract
  # field names from HTML, then POST matching params.
  def test_create_round_trip
    login("rolf")
    # First, render the new form
    get(:new, params: { observation_id: @obs1.id })
    assert_response(:success)
    body = @response.body

    # Extract the form action and method
    assert_match(%r{action="/occurrences"}, body,
                 "Form should POST to /occurrences")
    assert_match(/method="post"/, body,
                 "Form should use POST method")
    # Verify no nested forms (button_to inside form breaks submission)
    occ_form = body[%r{(<form[^>]*id="occurrence_form"[^>]*>.*?</form>)}m]
    nested = occ_form&.scan(/<form[^>]*>/)
    assert_equal(1, nested&.length,
                 "Form should have no nested <form> elements")

    # Now POST as the browser would with one recent obs checked
    assert_difference("Occurrence.count", 1) do
      post(:create, params: {
             observation_ids: [@obs1.id.to_s, @obs2.id.to_s],
             occurrence: {
               observation_id: @obs1.id.to_s,
               primary_observation_id: @obs1.id.to_s
             }
           })
    end
    occ = Occurrence.last
    assert_equal(2, occ.observations.count)
    assert_occurrence_redirect(occ)
  end

  # Verify the form generates correct field names for the
  # controller to parse.
  def test_new_form_stimulus_controller
    login("rolf")
    get(:new, params: { observation_id: @obs1.id })
    assert_response(:success)
    body = @response.body
    assert_match(/data-controller=".*occurrence-form.*"/, body)
    assert_match(
      /data-occurrence-form-target="sourceRadio"/, body
    )
  end

  def test_new_form_field_names
    login("rolf")
    get(:new, params: { observation_id: @obs1.id })
    assert_response(:success)
    body = @response.body
    # Source obs hidden field nested under occurrence[]
    assert_match(/name="occurrence\[observation_id\]"/, body)
    # observation_ids[] at top level
    assert_match(/name="observation_ids\[\]"/, body)
    # primary_observation_id nested under occurrence[]
    assert_match(
      /name="occurrence\[primary_observation_id\]"/, body
    )
  end

  def test_create_warns_if_locations_differ
    login("rolf")
    post(:create, params: create_params(@obs1, [@obs1, @obs2]))
    assert_flash_warning
  end

  def test_create_no_warning_if_locations_match
    login("rolf")
    obs3 = observations(:detailed_unknown_obs) # same location as obs1
    params = create_params(@obs1, [@obs1, obs3])
    params[:project_resolution] = "add_all"
    post(:create, params: params)
    assert_flash_success
  end

  def test_create_source_always_included
    login("rolf")
    # Don't include source in observation_ids — it should be added
    post(:create, params: create_params(@obs1, [@obs2]))
    occ = Occurrence.last
    assert_includes(occ.observations, @obs1)
    assert_includes(occ.observations, @obs2)
  end

  # ---------- project confirmation ----------

  def test_create_shows_project_confirmation
    login("rolf")
    obs3 = observations(:detailed_unknown_obs) # in boreal_project
    # No project_resolution param — should show confirmation
    assert_no_difference("Occurrence.count") do
      post(:create, params: create_params(@obs1, [@obs1, obs3]))
    end
    assert_response(:success) # renders confirmation modal
    assert_match(/Add All/, @response.body)
  end

  def test_create_with_add_all_adds_to_projects
    login("rolf")
    obs3 = observations(:detailed_unknown_obs) # in bolete_project
    project = projects(:bolete_project)
    params = create_params(@obs1, [@obs1, obs3])
    params[:project_resolution] = "add_all"
    assert_difference("Occurrence.count", 1) do
      post(:create, params: params)
    end
    occ = Occurrence.last
    assert_includes(@obs1.reload.projects, project,
                    "All obs should be added to all projects")
    assert_redirected_to(occurrence_path(occ))
  end

  # ---------- resolve_projects action ----------

  def test_resolve_projects_get_with_gaps
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, obs3)
    get(:resolve_projects, params: { id: occ.id })
    assert_response(:success)
  end

  def test_resolve_projects_get_no_gaps
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    get(:resolve_projects, params: { id: occ.id })
    assert_redirected_to(occurrence_path(occ))
  end

  def test_resolve_projects_post_add_all
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    project = projects(:bolete_project)
    occ = create_occurrence(@obs1, obs3)
    post(:resolve_projects,
         params: { id: occ.id, resolution: "add_all" })
    assert_includes(@obs1.reload.projects, project)
    assert_redirected_to(occurrence_path(occ))
  end

  def test_resolve_projects_post_cancel
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    project = projects(:bolete_project)
    occ = create_occurrence(@obs1, obs3)
    post(:resolve_projects, params: { id: occ.id })
    assert_not_includes(@obs1.reload.projects, project)
    assert_redirected_to(occurrence_path(occ))
  end

  # ---------- show action ----------

  def test_show_requires_login
    occ = create_occurrence(@obs1, @obs2)
    requires_login(:show, id: occ.id)
    assert_response(:success)
  end

  def test_show_displays_occurrence
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    get(:show, params: { id: occ.id })
    assert_response(:success)
    assert_match(@obs1.format_name.t, @response.body)
  end

  def test_show_missing_occurrence
    login("rolf")
    get(:show, params: { id: -1 })
    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_show_location_conflict
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    get(:show, params: { id: occ.id })
    assert_response(:success)
    assert_match(:show_occurrence_location_differs.l, @response.body)
  end

  # ---------- edit action ----------

  def test_edit_requires_login
    occ = create_occurrence(@obs1, @obs2)
    requires_login(:edit, id: occ.id)
    assert_response(:success)
  end

  def test_edit_displays_form
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    get(:edit, params: { id: occ.id })
    assert_response(:success)
    body = @response.body
    assert_match(/occurrence\[primary_observation_id\]/, body)
    assert_match(/observation_ids/, body)
  end

  def test_edit_allowed_for_non_creator
    login("mary")
    occ = create_occurrence(@obs1, @obs2)
    get(:edit, params: { id: occ.id })
    assert_response(:success)
  end

  def test_edit_missing_occurrence
    login("rolf")
    get(:edit, params: { id: -1 })
    assert_redirected_to(observations_path)
    assert_flash_error
  end

  # ---------- update action ----------

  def test_update_changes_primary
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    patch(:update, params: {
            id: occ.id,
            occurrence: { primary_observation_id: @obs2.id }
          })
    occ.reload
    assert_equal(@obs2, occ.primary_observation)
    assert_occurrence_redirect(occ)
    assert_flash_success
  end

  def test_update_removes_observation
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, @obs2, obs3)
    # Include only obs1 and obs3 (exclude obs2)
    patch(:update, params: {
            id: occ.id,
            observation_ids: [@obs1.id, obs3.id],
            occurrence: { primary_observation_id: @obs1.id }
          })
    occ.reload
    assert_equal(2, occ.observations.count)
    assert_not_includes(occ.observations, @obs2)
    @obs2.reload
    assert_nil(@obs2.occurrence_id)
  end

  def test_update_destroys_occurrence_if_too_few_remain
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    # Include only obs1 (exclude obs2)
    patch(:update, params: {
            id: occ.id,
            observation_ids: [@obs1.id],
            occurrence: { primary_observation_id: @obs1.id }
          })
    assert_not(Occurrence.exists?(occ.id))
  end

  def test_update_allowed_for_non_creator
    login("mary")
    occ = create_occurrence(@obs1, @obs2)
    patch(:update, params: {
            id: occ.id,
            occurrence: { primary_observation_id: @obs2.id }
          })
    occ.reload
    assert_equal(@obs2, occ.primary_observation)
    assert_flash_success
  end

  # ---------- update: removal permissions ----------

  def test_non_creator_can_remove_own_observation
    login("mary")
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, @obs2, obs3)
    # Include obs2 and obs3, exclude obs1 (mary's obs)
    patch(:update, params: {
            id: occ.id,
            observation_ids: [@obs2.id, obs3.id],
            occurrence: { primary_observation_id: @obs2.id }
          })
    occ.reload
    assert_not_includes(occ.observations, @obs1)
  end

  def test_non_creator_can_remove_others_observation
    login("mary")
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, @obs2, obs3)
    # Any logged-in user can edit occurrences
    patch(:update, params: {
            id: occ.id,
            observation_ids: [@obs1.id, obs3.id],
            occurrence: { primary_observation_id: @obs1.id }
          })
    occ.reload
    assert_not_includes(occ.observations, @obs2)
  end

  # ---------- update: add observations ----------

  def test_update_adds_observation
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, @obs2)
    # Include all existing + obs3
    patch(:update, params: {
            id: occ.id,
            observation_ids: [@obs1.id, @obs2.id, obs3.id],
            occurrence: { primary_observation_id: @obs1.id }
          })
    occ.reload
    assert_equal(3, occ.observations.count)
    assert_includes(occ.observations, obs3)
    # May render edit page with project modal or redirect
    assert_response(:success) if @response.redirect_url.nil?
    assert_flash_success
  end

  def test_update_add_merges_other_occurrence
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    obs4 = observations(:amateur_obs)
    occ1 = create_occurrence(@obs1, @obs2)
    occ2 = create_occurrence(obs3, obs4)
    # Include all existing + obs3 (which brings obs4 via merge)
    patch(:update, params: {
            id: occ1.id,
            observation_ids: [@obs1.id, @obs2.id, obs3.id],
            occurrence: { primary_observation_id: @obs1.id }
          })
    occ1.reload
    assert_equal(4, occ1.observations.count)
    assert_includes(occ1.observations, obs3)
    assert_includes(occ1.observations, obs4)
    assert_not(Occurrence.exists?(occ2.id))
  end

  def test_update_add_field_slip_conflict
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    fs1 = field_slips(:field_slip_one)
    fs2 = field_slips(:field_slip_two)
    occ = create_occurrence(@obs1, @obs2)
    occ.update!(field_slip: fs1)
    obs3_occ = Occurrence.create!(user: rolf,
                                  primary_observation: obs3,
                                  field_slip: fs2)
    obs3.update!(occurrence: obs3_occ)
    # Include all existing + obs3 (should fail: conflict)
    patch(:update, params: {
            id: occ.id,
            observation_ids: [@obs1.id, @obs2.id, obs3.id],
            occurrence: { primary_observation_id: @obs1.id }
          })
    occ.reload
    assert_equal(2, occ.observations.count)
    assert_not_includes(occ.observations, obs3)
    assert_flash_error
  end

  def test_edit_shows_candidate_observations
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    # Create a recent view so candidates appear
    obs3 = observations(:detailed_unknown_obs)
    ObservationView.create!(
      user: rolf, observation: obs3, last_view: Time.zone.now
    )
    get(:edit, params: { id: occ.id })
    assert_response(:success)
    assert_match(/observation_ids/, @response.body)
  end

  # ---------- update: location/date/create obs ----------

  def test_update_changes_primary_location
    login("rolf")
    loc2 = locations(:falmouth)
    obs_a = create_obs_with_location(rolf, locations(:burbank))
    obs_b = create_obs_with_location(rolf, loc2)
    occ = create_occurrence(obs_a, obs_b)

    patch(:update, params: {
            id: occ.id,
            occurrence: { primary_observation_id: obs_a.id },
            primary_obs: { location_id: loc2.id }
          })
    obs_a.reload
    assert_equal(loc2, obs_a.location)
    assert_equal(loc2.name, obs_a.where)
  end

  def test_update_changes_primary_date
    login("rolf")
    obs_a = create_obs_with_location(rolf, locations(:burbank))
    obs_b = create_obs_with_location(rolf, locations(:falmouth))
    occ = create_occurrence(obs_a, obs_b)
    new_date = "2025-06-15"

    patch(:update, params: {
            id: occ.id,
            occurrence: { primary_observation_id: obs_a.id },
            primary_obs: { when: new_date }
          })
    obs_a.reload
    assert_equal(Date.parse(new_date), obs_a.when)
  end

  def test_update_denied_obs_edit_without_permission
    obs_mary = create_obs_with_location(mary, locations(:burbank))
    obs_rolf = create_obs_with_location(rolf, locations(:falmouth))
    occ = Occurrence.create!(
      user: rolf, primary_observation: obs_mary
    )
    obs_mary.update!(occurrence: occ)
    obs_rolf.update!(occurrence: occ)
    login("rolf")

    original_loc = obs_mary.location_id
    patch(:update, params: {
            id: occ.id,
            occurrence: { primary_observation_id: obs_mary.id },
            primary_obs: { location_id: locations(:falmouth).id }
          })
    obs_mary.reload
    assert_equal(original_loc, obs_mary.location_id)
    assert_flash_error
  end

  def test_update_creates_observation
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    original_count = occ.observations.count

    assert_difference("Observation.count", 1) do
      patch(:update, params: {
              id: occ.id,
              occurrence: { primary_observation_id: @obs1.id },
              create_observation: "Create New Observation"
            })
    end
    occ.reload
    new_obs = occ.primary_observation
    assert_not_equal(@obs1, new_obs)
    assert_equal(@obs1.location, new_obs.location)
    assert_equal(@obs1.when, new_obs.when)
    assert_equal(rolf, new_obs.user)
    assert_equal(original_count + 1, occ.observations.count)
  end

  def test_edit_shows_details_section
    login("rolf")
    obs_a = create_obs_with_location(rolf, locations(:burbank))
    obs_b = create_obs_with_location(rolf, locations(:falmouth))
    occ = create_occurrence(obs_a, obs_b)

    get(:edit, params: { id: occ.id })
    assert_response(:success)
    body = @response.body
    # Location dropdown present when locations differ
    assert_match(/primary_obs\[location_id\]/, body)
    # Date and create button always present
    assert_match(/primary_obs\[when\]/, body)
    assert_match(/create_observation/, body)
    assert_match(/data-editable/, body)
  end

  # ---------- destroy action ----------

  def test_destroy_by_creator
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    assert_difference("Occurrence.count", -1) do
      delete(:destroy, params: { id: occ.id })
    end
    assert_flash_success
    @obs1.reload
    @obs2.reload
    assert_nil(@obs1.occurrence_id)
    assert_nil(@obs2.occurrence_id)
  end

  def test_destroy_allowed_for_any_user
    login("mary")
    occ = create_occurrence(@obs1, @obs2)
    assert_difference("Occurrence.count", -1) do
      delete(:destroy, params: { id: occ.id })
    end
    assert_flash_success
  end

  def test_destroy_redirects_to_primary_obs
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    delete(:destroy, params: { id: occ.id })
    assert_redirected_to(permanent_observation_path(@obs1.id))
  end

  def test_destroy_resets_cross_observation_thumbnails
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    img = images(:turned_over_image)
    @obs1.images << img
    # Set obs2's thumbnail to obs1's image (cross-obs)
    @obs2.update_column(:thumb_image_id, img.id)

    delete(:destroy, params: { id: occ.id })
    @obs2.reload

    # After destroy, obs2's thumbnail should be reset
    assert_not_equal(img.id, @obs2.thumb_image_id,
                     "Cross-obs thumbnail should be reset on destroy")
  end

  def test_destroy_recalculates_standalone_consensus
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)

    # Propose a name on obs1 and vote it up
    name = names(:agaricus_campestris)
    naming = Naming.create!(
      observation: @obs1, name: name, user: rolf
    )
    consensus = Observation::NamingConsensus.new(@obs1)
    consensus.change_vote(naming, Vote::MAXIMUM_VOTE, rolf)
    @obs2.reload
    shared_name_id = @obs2.name_id

    # obs2 should have the shared consensus
    assert_equal(name.id, shared_name_id)

    delete(:destroy, params: { id: occ.id })
    @obs2.reload

    # After destroy, obs2 should revert to its own consensus
    assert_not_equal(name.id, @obs2.name_id,
                     "Detached obs should revert to standalone consensus")
  end

  # ---------- update: sync_observations ----------

  def test_update_sync_adds_and_removes_observations
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    obs4 = observations(:amateur_obs)
    occ = create_occurrence(@obs1, @obs2, obs3)

    # Remove obs2, add obs4
    patch(:update, params: {
            id: occ.id,
            observation_ids: [@obs1.id, obs3.id, obs4.id],
            occurrence: { primary_observation_id: @obs1.id }
          })
    occ.reload
    assert_includes(occ.observations, obs4,
                    "obs4 should be added")
    assert_not_includes(occ.observations, @obs2,
                        "obs2 should be removed")
    assert_equal(3, occ.observations.count)
  end

  def test_update_parse_selected_ids_filters_zeros
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, @obs2, obs3)

    # Include a "0" id (empty checkbox) - should be ignored
    patch(:update, params: {
            id: occ.id,
            observation_ids: ["0", @obs1.id.to_s, @obs2.id.to_s],
            occurrence: { primary_observation_id: @obs1.id }
          })
    occ.reload
    # obs3 was excluded, but the "0" should not cause issues
    assert_equal(2, occ.observations.count)
    assert_not_includes(occ.observations, obs3)
  end

  private

  # Mirrors actual Superform output: observation_id and
  # primary_observation_id nested under occurrence[],
  # observation_ids[] at top level (raw input elements).
  def create_params(source, obs_list, primary: source)
    {
      observation_ids: obs_list.map(&:id),
      occurrence: {
        observation_id: source.id,
        primary_observation_id: primary.id
      }
    }
  end

  def create_obs_with_location(user, location)
    Observation.create!(
      user: user,
      name: names(:fungi),
      when: Time.zone.today,
      where: location.name,
      location: location
    )
  end

  # After create/update, redirect goes to either occurrence show or
  # resolve_projects (if project membership gaps exist).
  def assert_occurrence_redirect(occ)
    show = occurrence_path(occ)
    resolve = resolve_projects_occurrence_path(occ)
    assert_includes([show, resolve], @response.redirect_url.split("?").first.
                    sub(%r{^https?://[^/]+}, ""),
                    "Expected redirect to occurrence show or resolve_projects")
  end

  def create_occurrence(primary_obs, *other_obs)
    occ = Occurrence.create!(
      user: rolf,
      primary_observation: primary_obs
    )
    primary_obs.update!(occurrence: occ)
    other_obs.each { |obs| obs.update!(occurrence: occ) }
    occ
  end
end
