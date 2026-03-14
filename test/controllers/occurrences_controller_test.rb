# frozen_string_literal: true

require("test_helper")

class OccurrencesControllerTest < FunctionalTestCase
  def setup
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
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
                             default_observation: @obs1)
    @obs1.update!(occurrence: occ)

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
                    default_observation_id: @obs1.id }
    )
  end

  def test_create_success
    login("rolf")
    obs3 = observations(:detailed_unknown_obs) # same location as obs1
    assert_difference("Occurrence.count", 1) do
      post(:create, params: create_params(@obs1, [@obs1, obs3]))
    end
    occ = Occurrence.last
    assert_equal(@obs1, occ.default_observation)
    assert_equal(2, occ.observations.count)
    assert_redirected_to(permanent_observation_path(@obs1.id))
    assert_flash_success
  end

  def test_create_with_different_default
    login("rolf")
    post(:create, params: create_params(@obs1, [@obs1, @obs2],
                                        default: @obs2))
    occ = Occurrence.last
    assert_equal(@obs2, occ.default_observation)
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
                         default_observation_id: -1 }
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
               default_observation_id: @obs1.id.to_s
             }
           })
    end
    occ = Occurrence.last
    assert_equal(2, occ.observations.count)
    assert_redirected_to(permanent_observation_path(@obs1.id))
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
    # default_observation_id nested under occurrence[]
    assert_match(
      /name="occurrence\[default_observation_id\]"/, body
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
    post(:create, params: create_params(@obs1, [@obs1, obs3]))
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
    assert_match(/occurrence\[default_observation_id\]/, body)
    assert_match(/remove_observation_ids/, body)
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

  def test_update_changes_default
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    patch(:update, params: {
            id: occ.id,
            occurrence: { default_observation_id: @obs2.id }
          })
    occ.reload
    assert_equal(@obs2, occ.default_observation)
    assert_redirected_to(occurrence_path(occ))
    assert_flash_success
  end

  def test_update_removes_observation
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, @obs2, obs3)
    patch(:update, params: {
            id: occ.id,
            remove_observation_ids: [@obs2.id],
            occurrence: { default_observation_id: @obs1.id }
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
    patch(:update, params: {
            id: occ.id,
            remove_observation_ids: [@obs2.id],
            occurrence: { default_observation_id: @obs1.id }
          })
    assert_not(Occurrence.exists?(occ.id))
  end

  def test_update_allowed_for_non_creator
    login("mary")
    occ = create_occurrence(@obs1, @obs2)
    patch(:update, params: {
            id: occ.id,
            occurrence: { default_observation_id: @obs2.id }
          })
    occ.reload
    assert_equal(@obs2, occ.default_observation)
    assert_flash_success
  end

  # ---------- update: removal permissions ----------

  def test_non_creator_can_remove_own_observation
    login("mary")
    # @obs1 is owned by mary
    obs3 = observations(:detailed_unknown_obs) # owned by mary
    occ = create_occurrence(@obs1, @obs2, obs3)
    patch(:update, params: {
            id: occ.id,
            remove_observation_ids: [@obs1.id],
            occurrence: { default_observation_id: @obs2.id }
          })
    occ.reload
    assert_not_includes(occ.observations, @obs1)
  end

  def test_non_creator_cannot_remove_others_observation
    login("mary")
    # @obs2 (coprinus_comatus_obs) is owned by rolf
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, @obs2, obs3)
    patch(:update, params: {
            id: occ.id,
            remove_observation_ids: [@obs2.id],
            occurrence: { default_observation_id: @obs1.id }
          })
    occ.reload
    assert_includes(occ.observations, @obs2)
  end

  # ---------- update: add observations ----------

  def test_update_adds_observation
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    occ = create_occurrence(@obs1, @obs2)
    patch(:update, params: {
            id: occ.id,
            add_observation_ids: [obs3.id],
            occurrence: { default_observation_id: @obs1.id }
          })
    occ.reload
    assert_equal(3, occ.observations.count)
    assert_includes(occ.observations, obs3)
    assert_redirected_to(occurrence_path(occ))
    assert_flash_success
  end

  def test_update_add_merges_other_occurrence
    login("rolf")
    obs3 = observations(:detailed_unknown_obs)
    obs4 = observations(:amateur_obs)
    occ1 = create_occurrence(@obs1, @obs2)
    occ2 = create_occurrence(obs3, obs4)
    patch(:update, params: {
            id: occ1.id,
            add_observation_ids: [obs3.id],
            occurrence: { default_observation_id: @obs1.id }
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
    @obs1.update!(field_slip: fs1)
    obs3.update!(field_slip: fs2)
    occ = create_occurrence(@obs1, @obs2)
    patch(:update, params: {
            id: occ.id,
            add_observation_ids: [obs3.id],
            occurrence: { default_observation_id: @obs1.id }
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
    assert_match(/add_observation_ids/, @response.body)
  end

  # ---------- update: location/date/create obs ----------

  def test_update_changes_default_obs_location
    login("rolf")
    loc2 = locations(:falmouth)
    obs_a = create_obs_with_location(rolf, locations(:burbank))
    obs_b = create_obs_with_location(rolf, loc2)
    occ = create_occurrence(obs_a, obs_b)

    patch(:update, params: {
            id: occ.id,
            occurrence: { default_observation_id: obs_a.id },
            default_obs: { location_id: loc2.id }
          })
    obs_a.reload
    assert_equal(loc2, obs_a.location)
    assert_equal(loc2.name, obs_a.where)
  end

  def test_update_changes_default_obs_date
    login("rolf")
    obs_a = create_obs_with_location(rolf, locations(:burbank))
    obs_b = create_obs_with_location(rolf, locations(:falmouth))
    occ = create_occurrence(obs_a, obs_b)
    new_date = "2025-06-15"

    patch(:update, params: {
            id: occ.id,
            occurrence: { default_observation_id: obs_a.id },
            default_obs: { when: new_date }
          })
    obs_a.reload
    assert_equal(Date.parse(new_date), obs_a.when)
  end

  def test_update_denied_obs_edit_without_permission
    obs_mary = create_obs_with_location(mary, locations(:burbank))
    obs_rolf = create_obs_with_location(rolf, locations(:falmouth))
    occ = Occurrence.create!(
      user: rolf, default_observation: obs_mary
    )
    obs_mary.update!(occurrence: occ)
    obs_rolf.update!(occurrence: occ)
    login("rolf")

    original_loc = obs_mary.location_id
    patch(:update, params: {
            id: occ.id,
            occurrence: { default_observation_id: obs_mary.id },
            default_obs: { location_id: locations(:falmouth).id }
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
              occurrence: { default_observation_id: @obs1.id },
              create_observation: "Create New Observation"
            })
    end
    occ.reload
    new_obs = occ.default_observation
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
    assert_match(/default_obs\[location_id\]/, body)
    # Date and create button always present
    assert_match(/default_obs\[when\]/, body)
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

  def test_destroy_denied_for_non_creator
    login("mary")
    occ = create_occurrence(@obs1, @obs2)
    assert_no_difference("Occurrence.count") do
      delete(:destroy, params: { id: occ.id })
    end
    assert_flash_error
  end

  def test_destroy_redirects_to_default_obs
    login("rolf")
    occ = create_occurrence(@obs1, @obs2)
    delete(:destroy, params: { id: occ.id })
    assert_redirected_to(permanent_observation_path(@obs1.id))
  end

  private

  # Mirrors actual Superform output: observation_id and
  # default_observation_id nested under occurrence[],
  # observation_ids[] at top level (raw input elements).
  def create_params(source, obs_list, default: source)
    {
      observation_ids: obs_list.map(&:id),
      occurrence: {
        observation_id: source.id,
        default_observation_id: default.id
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

  def create_occurrence(default_obs, *other_obs)
    occ = Occurrence.create!(
      user: rolf,
      default_observation: default_obs
    )
    default_obs.update!(occurrence: occ)
    other_obs.each { |obs| obs.update!(occurrence: occ) }
    occ
  end
end
