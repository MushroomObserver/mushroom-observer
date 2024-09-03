# frozen_string_literal: true

require "test_helper"

class FieldSlipsControllerTest < FunctionalTestCase
  setup do
    @field_slip = field_slips(:field_slip_one)
  end

  test "should get index" do
    requires_login(:index)
    assert_response :success
  end

  test "should get new" do
    requires_login(:new)
    assert_response :success
  end

  test "should get new with right project if member" do
    project = projects(:bolete_project)
    login(project.user.login)
    code = "#{project.field_slip_prefix}-1234"
    get(:new, params: { code: code })
    assert_response :success
    assert(response.body.include?(project.title))
  end

  test "should get new with no project if not member" do
    project = projects(:bolete_project)
    login("lone_wolf") # Not a member of bolete_project
    code = "#{project.field_slip_prefix}-1234"
    get(:new, params: { code: code })
    assert_response :success
    assert(response.body.exclude?(project.title))
  end

  test "should get new with project if open" do
    project = projects(:open_membership_project)
    login("lone_wolf") # Not a member of open_project
    code = "#{project.field_slip_prefix}-1234"
    get(:new, params: { code: code })
    assert_response :success
    assert(response.body.include?(project.title))
  end

  test "should get new with inat import" do
    project = projects(:bolete_project)
    login(project.user.login)
    code = "#{project.field_slip_prefix}-1234"

    get(:new, params: { code: code })

    assert_response :success
    assert_select(
      "input[value=?]", :field_slip_import_from_inat.l, true,
      "Field Slip Record should have option to import iNat observation"
    )
  end

  test "should start inat import if inat import" do
    inat_id = "654321"
    inat_username = "anything"
    field_slip = field_slips(:field_slip_no_obs)
    field_slip_code = field_slip.code
    project = field_slip.project
    user = project.user

    login(user.login)
    post(:create, params: { commit: :field_slip_import_from_inat.l,
                            field_slip: { code: field_slip_code,
                                          other_codes: inat_id,
                                          inat_username: inat_username,
                                          project_id: project.id } })

    inat_import = InatImport.find_by(user: user)
    assert(inat_import.present?, "Failed to create InatImport object")
    assert_equal(user, inat_import.user)
    assert_equal(inat_id, inat_import.inat_ids)
    assert_equal(inat_username, inat_import.inat_username)

    assert_redirected_to(
      Observations::InatImportsController::INAT_AUTHORIZATION_URL
    )
  end

  test "should create field_slip with last viewed obs" do
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

    slip = FieldSlip.find_by(code: code)
    assert_redirected_to field_slip_url(slip)
    assert_equal(slip.observation, ObservationView.last(User.current))
  end

  test "should allow admin to create field_slip with constraint violation" do
    login("dick") # Admin of :falmouth_2023_09_project
    ObservationView.update_view_stats(@field_slip.observation_id,
                                      User.current.id)
    proj = projects(:falmouth_2023_09_project)
    code = "#{proj.field_slip_prefix}-1234"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_last_obs.t,
             field_slip: {
               code: code,
               project_id: proj.id
             }
           })
    end

    assert_flash_warning
    slip = FieldSlip.find_by(code: code)
    assert_redirected_to field_slip_url(slip)
    assert_equal(slip.observation, ObservationView.last(User.current))
  end

  test "should not create field_slip with last viewed obs due to constraints" do
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

  test "should create field_slip and join project" do
    user = @field_slip.user
    login(user.login)
    project = projects(:open_membership_project)
    assert_not(project.member?(user))
    ObservationView.update_view_stats(@field_slip.observation_id,
                                      @field_slip.user_id)
    code = "#{project.field_slip_prefix}-0001"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_last_obs.t,
             field_slip: {
               code: code,
               project_id: project.id
             }
           })
    end

    assert_redirected_to field_slip_url(FieldSlip.find_by(code: code))
    assert(project.member?(user))
  end

  test "should create field_slip and redirect to create obs" do
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
    assert_redirected_to new_observation_url(field_code: code)
  end

  test "should create field_slip and obs and redirect to show obs" do
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_quick_create_obs.t,
             field_slip: {
               code: code,
               location: locations(:albion).name,
               field_slip_id: names(:coprinus_comatus).text_name,
               project_id: projects(:eol_project).id
             }
           })
    end
    obs = Observation.last
    assert_redirected_to observation_url(obs.id)
  end

  test "should try to create obs and redirect to create obs" do
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
    assert_redirected_to new_observation_url(field_code: code)
  end

  test "should attempt quick field_slip and redirect to show obs" do
    login(@field_slip.user.login)
    code = "Z#{@field_slip.code}"
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             commit: :field_slip_quick_create_obs.t,
             field_slip: {
               code: code,
               location: locations(:albion).name,
               field_slip_id: names(:coprinus_comatus).text_name,
               project_id: projects(:eol_project).id
             }
           })
    end
    obs = Observation.last
    assert_redirected_to observation_url(obs.id)
  end

  test "should create field_slip in project from code" do
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

  test "should fail to create field_slip" do
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

  test "json should fail to create field_slip" do
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

  test "should show field_slip" do
    get(:show, params: { id: @field_slip.id })
    assert_response :success
  end

  test "should take admin to edit" do
    login(@field_slip.user.login)
    get(:show, params: { id: @field_slip.code })
    assert_redirected_to edit_field_slip_url(id: @field_slip.id)
  end

  test "should show field_slip and allow owner to change" do
    field_slip = field_slips(:field_slip_no_trust)
    login(field_slip.user.login)
    get(:show, params: { id: field_slip.id })
    assert_response :success
    assert(response.body.include?(:field_slip_edit.t))
  end

  test "should show field_slip by code" do
    get(:show, params: { id: @field_slip.code })
    assert_redirected_to observation_url(@field_slip.observation)
  end

  test "should redirect to get new" do
    login
    project = projects(:bolete_project)
    code = "#{project.field_slip_prefix}-1235"
    get(:show, params: { id: code })
    assert_redirected_to new_field_slip_url(code: code)
  end

  test "should get edit" do
    login(@field_slip.user.login)
    get(:edit, params: { id: @field_slip.id })
    assert_response :success
  end

  test "admin should get edit" do
    login("rolf")
    get(:edit, params: { id: @field_slip.id })
    assert_response :success
  end

  test "admin should not get edit when no trust" do
    login("rolf")
    field_slip = field_slips(:field_slip_no_trust)
    get(:edit, params: { id: field_slip.id })
    assert_redirected_to field_slip_url(field_slip)
  end

  test "should get not edit" do
    login("dick")
    get(:edit, params: { id: @field_slip.id })
    assert_redirected_to field_slip_url(@field_slip)
  end

  test "should update field_slip" do
    login
    initial = @field_slip.observation_id
    notes = "Some notes"
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_keep_obs.t,
                    field_slip: { code: @field_slip.code,
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id,
                                  notes: { Other: notes } } })
    assert_redirected_to field_slip_url(@field_slip)
    assert_equal(@field_slip.observation_id, initial)
    assert_equal(@field_slip.observation.notes[:Other], notes)
  end

  test "should update field_slip with new name" do
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
                      field_slip_id: names(:coprinus_comatus).text_name,
                      field_slip_id_by: "#{user.login} <#{user.name}>",
                      project_id: @field_slip.project_id,
                      notes: { Other: notes }
                    } })
    assert_redirected_to field_slip_url(@field_slip)
    assert_equal(@field_slip.observation_id, initial)
    assert_equal(@field_slip.observation.name, names(:coprinus_comatus))
    assert_equal(@field_slip.observation.notes[:Other], notes)
  end

  test "should update field_slip and clear other notes" do
    field_slip = field_slips(:field_slip_falmouth_one)
    assert(field_slip.observation.notes[:Other].present?)
    login
    patch(:update,
          params: { id: field_slip.id,
                    commit: :field_slip_keep_obs.t,
                    field_slip: { code: field_slip.code,
                                  observation_id: field_slip.observation_id,
                                  project_id: field_slip.project_id,
                                  notes: { Other: "" } } })
    assert_redirected_to field_slip_url(field_slip)
    assert(field_slip.observation.reload.notes[:Other].blank?)
  end

  test "should update field_slip with last viewed obs" do
    login(@field_slip.user.login)
    orig_obs = @field_slip.observation
    obs = observations(:detailed_unknown_obs)
    ObservationView.update_view_stats(obs.id, @field_slip.user_id)
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_last_obs.t,
                    field_slip: { code: @field_slip.code,
                                  project_id: @field_slip.project_id } })
    assert_redirected_to field_slip_url(@field_slip)
    assert_equal(@field_slip.reload.observation,
                 ObservationView.last(User.current))
    assert(@field_slip.project.observations.include?(obs))
    assert_not(@field_slip.project.observations.include?(orig_obs))
  end

  test "should not remove obs from project when multiple reasons" do
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
    assert_redirected_to field_slip_url(field_slip)
    assert(field_slip.project.observations.include?(orig_obs))
  end

  test "should update field_slip and redirect to create obs" do
    login
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_create_obs.t,
                    field_slip: { code: @field_slip.code,
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_redirected_to new_observation_url(field_code: @field_slip.code)
  end

  test "should fail to update field_slip" do
    login
    patch(:update,
          params: { id: @field_slip.id,
                    field_slip: { code: "-3.14",
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_equal(response.status, 422)
  end

  test "json should fail to update field_slip" do
    login
    patch(:update,
          format: :json,
          params: { id: @field_slip.id,
                    field_slip: { code: "-3.14",
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_equal(response.status, 422)
  end

  test "should destroy field_slip" do
    login(@field_slip.user.login)
    assert_difference("FieldSlip.count", -1) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to field_slips_url
  end

  test "admin should be able to destroy field_slip" do
    login
    assert_difference("FieldSlip.count", -1) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to field_slips_url
  end

  test "should not destroy field_slip" do
    login("dick")
    assert_difference("FieldSlip.count", 0) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to field_slip_url(@field_slip)
  end
end
