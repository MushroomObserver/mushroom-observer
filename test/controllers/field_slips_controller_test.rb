# frozen_string_literal: true

require("test_helper")

class FieldSlipsControllerTest < FunctionalTestCase
  setup do
    @field_slip = field_slips(:field_slip_one)
  end

  def test_should_get_index
    requires_login(:index)
    assert_response(:success)
  end

  def test_should_get_index_at_id
    oldest = field_slips(:field_slip_by_recorder)
    requires_login(:index, id: oldest.id)
    assert_response(:success)
  end

  def test_should_get_index_for_project
    requires_login(:index, project: @field_slip.project.id)
    assert_response(:success)
  end

  def test_should_get_index_for_user
    requires_login(:index, by_user: @field_slip.user.id)
    assert_response(:success)
  end

  def test_should_get_new
    requires_login(:new)
    assert_response(:success)
  end

  def test_should_get_new_with_right_project_if_member
    project = projects(:bolete_project)
    login(project.user.login)
    code = "#{project.field_slip_prefix}-1234"
    get(:new, params: { code: code })
    assert_response(:success)
    assert(response.body.include?(project.title))
  end

  def test_should_get_new_with_no_project_if_not_member
    project = projects(:bolete_project)
    login("lone_wolf") # Not a member of bolete_project
    code = "#{project.field_slip_prefix}-1234"
    get(:new, params: { code: code })
    assert_response(:success)
    assert(response.body.exclude?(project.title))
  end

  def test_should_get_new_with_project_if_open
    project = projects(:open_membership_project)
    login("lone_wolf") # Not a member of open_project
    code = "#{project.field_slip_prefix}-1234"
    get(:new, params: { code: code })
    assert_response(:success)
    assert(response.body.include?(project.title))
    assert_select('input[name="field_slip[collector]"]:not([value])')
  end

  def test_should_create_field_slip_with_last_viewed_obs
    login(@field_slip.user.login)
    ObservationView.update_view_stats(@field_slip.observation_id,
                                      @field_slip.user_id)
    code = "Y#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_last_obs.t,
             field_slip: {
               code: code,
               project_id: projects(:eol_project).id
             }
           })
    end
  end

  def test_should_change_collector_of_last_viewed_obs_if_owner
    login(@field_slip.user.login)
    ObservationView.update_view_stats(@field_slip.observation_id,
                                      @field_slip.user_id)
    code = "Y#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_last_obs.t,
             field_slip: {
               code: code,
               project_id: projects(:eol_project).id,
               collector: rolf.login
             }
           })
    end

    slip = FieldSlip.find_by(code: code)
    assert_equal(rolf.textile_name, slip.collector)
    assert_redirected_to(observation_url(slip.observation))
    assert_equal(slip.observation, ObservationView.last(@field_slip.user))
  end

  def test_should_not_change_collector_of_last_viewed_obs_if_not_owner
    login(rolf.login)
    ObservationView.update_view_stats(@field_slip.observation_id,
                                      rolf.id)
    collector = @field_slip.collector
    code = "Y#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_last_obs.t,
             field_slip: {
               code: code,
               project_id: projects(:eol_project).id,
               collector: rolf.login
             }
           })
    end

    slip = FieldSlip.find_by(code: code)
    assert_equal(collector, slip.collector)
    assert_redirected_to(observation_url(slip.observation))
    assert_equal(slip.observation, ObservationView.last(rolf.id))
  end

  def test_disallow_admin_to_create_field_slip_with_constraint_violation
    user = users(:dick)
    login(user.login) # Admin of :falmouth_2023_09_project
    ObservationView.update_view_stats(@field_slip.observation_id,
                                      user.id)
    proj = projects(:falmouth_2023_09_project)
    code = "#{proj.field_slip_prefix}-1234"
    assert_difference("FieldSlip.count", 0) do
      post(:create,
           params: {
             commit: :field_slip_last_obs.t,
             field_slip: {
               code: code,
               project_id: proj.id
             }
           })
    end

    assert_flash_error
    assert_equal(response.status, 422)
  end

  def test_should_not_create_field_slip_with_last_viewed_obs_due_to_constraints
    login(@field_slip.user.login)
    ObservationView.update_view_stats(@field_slip.observation_id,
                                      @field_slip.user_id)
    proj = projects(:falmouth_2023_09_project)
    code = "#{proj.field_slip_prefix}-1234"
    assert_difference("FieldSlip.count", 0) do
      post(:create,
           params: {
             commit: :field_slip_last_obs.t,
             field_slip: {
               code: code,
               project_id: proj.id
             }
           })
    end

    assert_flash_error
    assert_nil(FieldSlip.find_by(code: code))
    assert_equal(response.status, 422)
  end

  def test_should_create_field_slip_and_join_project
    user = @field_slip.user
    login(user.login)
    project = projects(:open_membership_project)
    species_list = project.species_lists.first
    assert_not(project.member?(user))
    ObservationView.update_view_stats(@field_slip.observation_id,
                                      @field_slip.user_id)
    code = "#{project.field_slip_prefix}-0001"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_last_obs.t,
             species_list: species_list.id,
             field_slip: {
               code: code,
               project_id: project.id
             }
           })
    end

    fs = FieldSlip.find_by(code: code)
    assert(fs.user)
    obs = fs.observation
    assert_redirected_to(observation_url(obs))
    assert(project.member?(user))
    assert(project.observations.member?(obs))
    assert(species_list.observations.member?(obs))
  end

  def test_should_create_field_slip_and_redirect_to_create_obs
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_add_images.t,
             field_slip: {
               code: code,
               project_id: projects(:eol_project).id
             }
           })
    end
    assert_redirected_to(new_observation_url(field_code: code))
  end

  def test_should_create_field_slip_using_aliases
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_quick_create_obs.t,
             field_slip: {
               code: code,
               project_id: projects(:eol_project).id,
               field_slip_id_by: project_aliases(:one).name,
               location: project_aliases(:two).name
             }
           })
    end
    field_slip = FieldSlip.find_by(code: code)
    assert_equal(field_slip.observation.location, project_aliases(:two).target)
    assert_equal(project_aliases(:one).target.textile_name,
                 field_slip.observation.notes[:Field_Slip_ID_By])
  end

  def test_should_create_field_slip_and_obs_and_redirect_to_show_obs
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    date = Date.new(2000, 1, 2)
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_quick_create_obs.t,
             field_slip: {
               code: code,
               "date(1i)" => date.year.to_s,
               "date(2i)" => date.month.to_s,
               "date(3i)" => date.day.to_s,
               location: locations(:albion).name,
               field_slip_name: names(:coprinus_comatus).text_name,
               project_id: projects(:eol_project).id
             }
           })
    end
    obs = Observation.last
    assert_equal(date, obs.when)
    assert_redirected_to(observation_url(obs.id))
  end

  def test_should_create_obs_with_link_to_inat
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    assert_difference("Observation.count") do
      post(:create,
           params: {
             commit: :field_slip_quick_create_obs.t,
             field_slip: {
               code: code,
               location: locations(:albion).name,
               field_slip_name: names(:coprinus_comatus).text_name,
               # project_id: projects(:eol_project).id,
               other_codes: "12345",
               inat: "1"
             }
           })
    end
    obs = Observation.last
    assert_match("https://www.inaturalist.org/observations",
                 obs.notes[:Other_Codes])
  end

  def test_should_try_to_create_obs_and_redirect_to_create_obs
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_quick_create_obs.t,
             field_slip: {
               code: code,
               project_id: projects(:eol_project).id
             }
           })
    end
    assert_flash_error
    assert_redirected_to(new_observation_url(field_code: code))
  end

  def test_should_create_fungi_obs
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_quick_create_obs.t,
             field_slip: {
               location: locations(:albion).name,
               code: code,
               project_id: projects(:eol_project).id
             }
           })
    end
    obs = Observation.last
    assert_redirected_to(observation_url(obs.id))
    assert_equal(obs.text_name, "Fungi")
  end

  def test_should_attempt_quick_field_slip_and_redirect_to_show_obs
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_quick_create_obs.t,
             field_slip: {
               code: code,
               location: locations(:albion).name,
               field_slip_name: names(:coprinus_comatus).text_name,
               project_id: projects(:eol_project).id
             }
           })
    end
    obs = Observation.last
    assert_redirected_to(observation_url(obs.id))
  end

  def test_should_create_field_slip_in_project_from_code
    login
    project = projects(:eol_project)
    code = "#{project.field_slip_prefix}-1234"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             field_slip: {
               code: code
             }
           })
    end
    field_slip = FieldSlip.find_by(code: code)
    assert_equal(field_slip.project, project)
  end

  def test_should_fail_to_create_field_slip
    login
    post(:create,
         params: {
           field_slip: {
             code: @field_slip.code.to_s,
             observation: observations(:coprinus_comatus_obs),
             project_id: projects(:eol_project).id
           }
         })
    assert_equal(response.status, 422)
  end

  def test_json_should_fail_to_create_field_slip
    login
    post(:create,
         format: :json,
         params: {
           field_slip: {
             code: @field_slip.code.to_s,
             observation: observations(:coprinus_comatus_obs),
             project_id: projects(:eol_project).id
           }
         })
    assert_equal(response.status, 422)
  end

  def test_should_show_field_slip
    get(:show, params: { id: @field_slip.id })
    assert_response(:success)
  end

  def test_should_take_admin_to_edit
    login(@field_slip.user.login)
    get(:show, params: { id: @field_slip.code })
    assert_redirected_to(observation_url(@field_slip.observation))
    # assert_redirected_to edit_field_slip_url(id: @field_slip.id)
  end

  def test_should_show_field_slip_and_allow_owner_to_change
    field_slip = field_slips(:field_slip_no_trust)
    login(field_slip.user.login)
    get(:show, params: { id: field_slip.id })
    assert_response(:success)
    assert(response.body.include?(:field_slip_edit.t))
  end

  def test_should_show_field_slip_by_code
    get(:show, params: { id: @field_slip.code })
    assert_redirected_to(observation_url(@field_slip.observation))
  end

  def test_should_redirect_to_get_new
    login
    project = projects(:bolete_project)
    code = "#{project.field_slip_prefix}-1235"
    get(:show, params: { id: code })
    assert_redirected_to(new_field_slip_url(code: code, id: code))
  end

  def test_show_project_prphan_has_edit_link
    login
    fs = field_slips(:field_slip_project_orphan)
    get(:show, params: { id: fs.id })
    assert_response(:success)
    assert_match(/#{:field_slip_edit.t}/, @response.body)
  end

  def test_should_get_edit
    login(@field_slip.user.login)
    get(:edit, params: { id: @field_slip.id })
    assert_response(:success)
  end

  def test_should_show_field_slip_location
    login(@field_slip.user.login)
    get(:edit, params: { id: @field_slip.id })
    assert_match(@field_slip.location_name,
                 @response.body)
  end

  def test_should_show_text_collector
    field_slip = field_slips(:field_slip_by_recorder)
    login(field_slip.user.login)
    get(:edit, params: { id: field_slip.id })
    assert_match(field_slip.observation.collector,
                 @response.body)
  end

  def test_should_show_previous_field_slip_location
    field_slip = field_slips(:field_slip_previous)
    assert_not(field_slip.location == field_slip.project.location.display_name)
    login(field_slip.user.login)
    get(:new, params: { code: "#{field_slip.code}0" })
    assert_match(field_slip.location_name,
                 @response.body)
  end

  def test_should_show_project_location
    login(@field_slip.user.login)
    project = projects(:current_project)
    get(:new, params: { code: "#{project.field_slip_prefix}-1234" })
    assert_match(project.location.display_name,
                 @response.body)
  end

  def test_should_edit_user_orphan
    fs = field_slips(:field_slip_user_orphan)
    login(mary.login)
    get(:edit, params: { id: fs.id })
    assert_response(:success)
    # Create a new observation for this test instead of using Observation.last
    # to avoid deadlocks with other tests in the suite
    obs = Observation.create!(
      user: mary,
      when: Time.zone.now,
      where: "Test Location",
      name: names(:fungi)
    )
    fs.observation = obs
    fs.save!
    assert_equal(obs.user, fs.user)
  end

  def test_admin_should_get_edit
    login("rolf")
    get(:edit, params: { id: @field_slip.id })
    assert_response(:success)
  end

  def test_admin_should_not_get_edit_when_no_trust
    login("rolf")
    field_slip = field_slips(:field_slip_no_trust)
    get(:edit, params: { id: field_slip.id })
    assert_redirected_to(field_slip_url(field_slip))
  end

  def test_should_get_not_edit
    login("dick")
    get(:edit, params: { id: @field_slip.id })
    assert_redirected_to(field_slip_url(@field_slip))
  end

  def test_should_update_field_slip
    login
    initial = @field_slip.observation_id
    obs = Observation.find(initial)
    notes = "Some notes"
    obs_date = obs.when
    date = Date.new(2000, 1, 2) # Try to override the date
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_keep_obs.t,
                    field_slip: { code: @field_slip.code,
                                  "date(1i)" => date.year.to_s,
                                  "date(2i)" => date.month.to_s,
                                  "date(3i)" => date.day.to_s,
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id,
                                  notes: { Other: notes } } })
    assert_redirected_to(field_slip_url(@field_slip))
    assert_equal(@field_slip.observation_id, initial)
    obs.reload
    assert(obs.notes[:Other].include?(notes))
    assert_equal(obs_date, obs.when) # Observation wins
  end

  def test_should_update_field_slip_with_new_name
    login
    user = users(:rolf)
    initial = @field_slip.observation_id
    notes = "New notes"
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_keep_obs.t,
                    field_slip: {
                      code: @field_slip.code,
                      observation_id: @field_slip.observation_id,
                      field_slip_name: names(:coprinus_comatus).text_name,
                      field_slip_id_by: "#{user.name} (#{user.login})",
                      project_id: @field_slip.project_id,
                      notes: { Other: notes }
                    } })
    assert_redirected_to(field_slip_url(@field_slip))
    assert_equal(@field_slip.observation_id, initial)
    assert_equal(@field_slip.observation.name, names(:coprinus_comatus))
    assert_equal(@field_slip.observation.notes[:Other], notes)
  end

  def test_should_preserve_underscores_in_id_when_editing_other_fields
    login
    obs = @field_slip.observation
    # Set ID field with underscores (textile italic format)
    id_with_underscores = "_name Agaricus campestris_"
    obs.notes[:Field_Slip_ID] = id_with_underscores
    obs.save!

    # Update a different field (not the ID field)
    new_notes = "Additional notes"
    patch(:update,
          params: {
            id: @field_slip.id,
            commit: :field_slip_keep_obs.t,
            field_slip: {
              code: @field_slip.code,
              observation_id: @field_slip.observation_id,
              project_id: @field_slip.project_id,
              field_slip_name: id_with_underscores,
              notes: { Other: new_notes }
            }
          })

    assert_redirected_to(field_slip_url(@field_slip))
    obs.reload

    # Verify ID field still has underscores (not stripped to "name Agaricus...")
    assert_equal(
      id_with_underscores,
      obs.notes[:Field_Slip_ID],
      "ID field should preserve underscores when editing other fields"
    )
    assert_equal(new_notes, obs.notes[:Other])
  end

  def test_check_name_handles_textile_formats
    login

    # Test "_name Xxx yyy_" format - should create naming with correct name
    fs1 = field_slips(:field_slip_one)
    patch(:update,
          params: {
            id: fs1.id,
            commit: :field_slip_keep_obs.t,
            field_slip: {
              code: fs1.code,
              observation_id: fs1.observation_id,
              project_id: fs1.project_id,
              field_slip_name: "_name #{names(:coprinus_comatus).text_name}_"
            }
          })
    assert_redirected_to(field_slip_url(fs1))
    # Check that a naming was created for this name
    naming_exists = fs1.observation.reload.namings.exists?(
      name: names(:coprinus_comatus)
    )
    assert(naming_exists, "Should create naming for '_name Xxx yyy_' format")

    # Test "_Xxx yyy_" format (without "name" prefix)
    fs2 = field_slips(:field_slip_two)
    patch(:update,
          params: {
            id: fs2.id,
            commit: :field_slip_keep_obs.t,
            field_slip: {
              code: fs2.code,
              observation_id: fs2.observation_id,
              project_id: fs2.project_id,
              field_slip_name: "_#{names(:agaricus_campestris).text_name}_"
            }
          })
    assert_redirected_to(field_slip_url(fs2))
    naming_exists = fs2.observation.reload.namings.exists?(
      name: names(:agaricus_campestris)
    )
    assert(naming_exists, "Should create naming for '_Xxx yyy_' format")

    # Test plain format (no underscores)
    fs3 = field_slips(:field_slip_previous)
    patch(:update,
          params: {
            id: fs3.id,
            commit: :field_slip_keep_obs.t,
            field_slip: {
              code: fs3.code,
              observation_id: fs3.observation_id,
              project_id: fs3.project_id,
              field_slip_name: names(:boletus_edulis).text_name
            }
          })
    assert_redirected_to(field_slip_url(fs3))
    naming_exists = fs3.observation.reload.namings.exists?(
      name: names(:boletus_edulis)
    )
    assert(naming_exists, "Should create naming for plain 'Xxx yyy' format")
  end

  def test_should_update_field_slip_and_merge_notes
    field_slip = field_slips(:field_slip_falmouth_one)
    old_note = field_slip.observation.notes[:Other]
    new_note = "New notes"
    login
    patch(:update,
          params: { id: field_slip.id,
                    commit: :field_slip_keep_obs.t,
                    field_slip: { code: field_slip.code,
                                  observation_id: field_slip.observation_id,
                                  project_id: field_slip.project_id,
                                  notes: { Other: new_note } } })
    assert_redirected_to(field_slip_url(field_slip))
    notes = field_slip.observation.reload.notes[:Other]
    assert(notes.include?(old_note))
    assert(notes.include?(new_note))
  end

  def test_should_update_field_slip_and_same_note
    field_slip = field_slips(:field_slip_falmouth_one)
    old_note = field_slip.observation.notes[:Other]
    login
    patch(:update,
          params: { id: field_slip.id,
                    commit: :field_slip_keep_obs.t,
                    field_slip: { code: field_slip.code,
                                  observation_id: field_slip.observation_id,
                                  project_id: field_slip.project_id,
                                  notes: { Other: old_note } } })
    assert_redirected_to(field_slip_url(field_slip))
    notes = field_slip.observation.reload.notes[:Other]
    assert_equal(old_note, notes)
  end

  def test_should_update_field_slip_and_more_notes
    field_slip = field_slips(:field_slip_falmouth_one)
    old_note = field_slip.observation.notes[:Other]
    new_note = "Start\n#{old_note}\nEnd"
    login
    patch(:update,
          params: { id: field_slip.id,
                    commit: :field_slip_keep_obs.t,
                    field_slip: { code: field_slip.code,
                                  observation_id: field_slip.observation_id,
                                  project_id: field_slip.project_id,
                                  notes: { Other: new_note } } })
    assert_redirected_to(field_slip_url(field_slip))
    notes = field_slip.observation.reload.notes[:Other]
    assert_equal(new_note, notes)
  end

  def test_should_update_field_slip_with_last_viewed_obs
    user = @field_slip.user
    login(user.login)
    orig_obs = @field_slip.observation
    obs = observations(:detailed_unknown_obs)
    ObservationView.update_view_stats(obs.id, user.id)
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_last_obs.t,
                    field_slip: { code: @field_slip.code,
                                  project_id: @field_slip.project_id } })
    assert_redirected_to(field_slip_url(@field_slip))
    assert_equal(@field_slip.reload.observation,
                 ObservationView.last(user))
    assert(@field_slip.project.observations.include?(obs))
    assert_not(@field_slip.project.observations.include?(orig_obs))
  end

  def test_should_not_remove_obs_from_project_when_multiple_reasons
    field_slip = field_slips(:field_slip_nowhere_one)
    field_slips(:field_slip_nowhere_dup)
    login(field_slip.user.login)
    orig_obs = field_slip.observation
    obs = observations(:detailed_unknown_obs)
    ObservationView.update_view_stats(obs.id, field_slip.user_id)
    patch(:update,
          params: { id: field_slip.id,
                    commit: :field_slip_last_obs.t,
                    field_slip: { code: field_slip.code,
                                  project_id: field_slip.project_id } })
    assert_redirected_to(field_slip_url(field_slip))
    assert(field_slip.project.observations.include?(orig_obs))
  end

  def test_should_update_field_slip_and_redirect_to_create_obs
    login
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_create_obs.t,
                    field_slip: { code: @field_slip.code,
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_redirected_to(new_observation_url(field_code: @field_slip.code))
  end

  def test_should_fail_to_update_field_slip
    login
    patch(:update,
          params: { id: @field_slip.id,
                    field_slip: { code: "-3.14",
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_equal(response.status, 422)
  end

  def test_json_should_fail_to_update_field_slip
    login
    patch(:update,
          format: :json,
          params: { id: @field_slip.id,
                    field_slip: { code: "-3.14",
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_equal(response.status, 422)
  end

  def test_should_destroy_field_slip
    login(@field_slip.user.login)
    assert_difference("FieldSlip.count", -1) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to(field_slips_url)
  end

  def test_admin_should_be_able_to_destroy_field_slip
    login
    assert_difference("FieldSlip.count", -1) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to(field_slips_url)
  end

  def test_should_not_destroy_field_slip
    login("dick")
    assert_difference("FieldSlip.count", 0) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to(field_slip_url(@field_slip))
  end
end
