# frozen_string_literal: true

require "application_system_test_case"

class FieldSlipsTest < ApplicationSystemTestCase
  setup do
    @field_slip = field_slips(:one)
  end

  test "visiting the index" do
    visit field_slips_url
    assert_selector "h1", text: "Field slips"
  end

  test "should create field slip" do
    visit field_slips_url
    click_on "New field slip"

    fill_in "Code", with: @field_slip.code
    fill_in "Observation", with: @field_slip.observation_id
    fill_in "Project", with: @field_slip.project_id
    click_on "Create Field slip"

    assert_text "Field slip was successfully created"
    click_on "Back"
  end

  test "should update Field slip" do
    visit field_slip_url(@field_slip)
    click_on "Edit this field slip", match: :first

    fill_in "Code", with: @field_slip.code
    fill_in "Observation", with: @field_slip.observation_id
    fill_in "Project", with: @field_slip.project_id
    click_on "Update Field slip"

    assert_text "Field slip was successfully updated"
    click_on "Back"
  end

  test "should destroy Field slip" do
    visit field_slip_url(@field_slip)
    click_on "Destroy this field slip", match: :first

    assert_text "Field slip was successfully destroyed"
  end
end
