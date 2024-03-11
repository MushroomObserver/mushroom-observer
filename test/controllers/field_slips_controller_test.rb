require "test_helper"

class FieldSlipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @field_slip = field_slips(:one)
  end

  test "should get index" do
    get field_slips_url
    assert_response :success
  end

  test "should get new" do
    get new_field_slip_url
    assert_response :success
  end

  test "should create field_slip" do
    assert_difference("FieldSlip.count") do
      post field_slips_url, params: { field_slip: { code: @field_slip.code, observation_id: @field_slip.observation_id, project_id: @field_slip.project_id } }
    end

    assert_redirected_to field_slip_url(FieldSlip.last)
  end

  test "should show field_slip" do
    get field_slip_url(@field_slip)
    assert_response :success
  end

  test "should get edit" do
    get edit_field_slip_url(@field_slip)
    assert_response :success
  end

  test "should update field_slip" do
    patch field_slip_url(@field_slip), params: { field_slip: { code: @field_slip.code, observation_id: @field_slip.observation_id, project_id: @field_slip.project_id } }
    assert_redirected_to field_slip_url(@field_slip)
  end

  test "should destroy field_slip" do
    assert_difference("FieldSlip.count", -1) do
      delete field_slip_url(@field_slip)
    end

    assert_redirected_to field_slips_url
  end
end
