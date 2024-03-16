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

  test "should create field_slip" do
    login
    assert_difference("FieldSlip.count") do
      post(:create,
           params: {
             field_slip: {
               code: "X#{@field_slip.code}",
               observation: observations(:coprinus_comatus_obs),
               project: projects(:eol_project)
             }
           })
    end

    assert_redirected_to field_slip_url(FieldSlip.last)
  end

  test "should show field_slip" do
    get(:show, params: { id: @field_slip.id })
    assert_response :success
  end

  test "should get edit" do
    login
    get(:edit, params: { id: @field_slip.id })
    assert_response :success
  end

  test "should update field_slip" do
    login
    patch(:update,
          params: { id: @field_slip.id,
                    field_slip: { code: @field_slip.code,
                                  observation_id: @field_slip.observation_id,
                                  project_id: @field_slip.project_id } })
    assert_redirected_to field_slip_url(@field_slip)
  end

  test "should destroy field_slip" do
    login
    assert_difference("FieldSlip.count", -1) do
      delete(:destroy, params: { id: @field_slip.id })
    end

    assert_redirected_to field_slips_url
  end
end
