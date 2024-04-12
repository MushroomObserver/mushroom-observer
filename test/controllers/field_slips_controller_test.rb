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

  test "should get new with unknown code" do
    login
    project = projects(:bolete_project)
    code = "#{project.field_slip_prefix}-1234"
    get(:new, params: { code: code })
    assert_response :success
    assert(response.body.include?(project.title))
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
               project: projects(:eol_project)
             }
           })
    end

    slip = FieldSlip.find_by(code: code)
    assert_redirected_to field_slip_url(slip)
    assert_equal(slip.observation, ObservationView.last(User.current))
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
               project: project
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
             commit: :field_slip_create_obs.t,
             field_slip: {
               code: code,
               project: projects(:eol_project)
             }
           })
    end
    assert_redirected_to new_observation_url(field_code: code)
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
             project: projects(:eol_project)
           }
         })
    assert_response 422
  end

  test "json should fail to create field_slip" do
    login
    post(:create,
         format: :json,
         params: {
           field_slip: {
             code: @field_slip.code.to_s,
             observation: observations(:coprinus_comatus_obs),
             project: projects(:eol_project)
           }
         })
    assert_response 422
  end

  test "should show field_slip" do
    get(:show, params: { id: @field_slip.id })
    assert_response :success
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

  test "should get not edit" do
    login
    get(:edit, params: { id: @field_slip.id })
    assert_redirected_to field_slip_url(@field_slip)
  end

  test "should update field_slip" do
    login
    initial = @field_slip.observation_id
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_keep_obs.t,
                    field_slip: { code: @field_slip.code,
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_redirected_to field_slip_url(@field_slip)
    assert_equal(@field_slip.observation_id, initial)
  end

  test "should update field_slip with last viewed obs" do
    login(@field_slip.user.login)
    obs = observations(:minimal_unknown_obs)
    ObservationView.update_view_stats(obs.id, @field_slip.user_id)
    patch(:update,
          params: { id: @field_slip.id,
                    commit: :field_slip_last_obs.t,
                    field_slip: { code: @field_slip.code,
                                  project_id: @field_slip.project_id } })
    assert_redirected_to field_slip_url(@field_slip)
    assert_equal(@field_slip.observation, ObservationView.last(User.current))
    assert(@field_slip.project.observations.include?(obs))
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
    assert_response 422
  end

  test "json should fail to update field_slip" do
    login
    patch(:update,
          format: :json,
          params: { id: @field_slip.id,
                    field_slip: { code: "-3.14",
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_response 422
  end

  test "should destroy field_slip" do
    login(@field_slip.user.login)
    assert_difference("FieldSlip.count", -1) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to field_slips_url
  end

  test "should not destroy field_slip" do
    login
    assert_difference("FieldSlip.count", 0) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to field_slip_url(@field_slip)
  end
end
