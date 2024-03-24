# frozen_string_literal: true

require "application_system_test_case"

class FieldSlipsTest < ApplicationSystemTestCase
  setup do
    @field_slip = field_slips(:field_slip_one)
  end

  test "visiting the index" do
    login!(mary)
    visit field_slips_url
    assert_selector "h1", text: :FIELD_SLIPS.t
  end

  test "navigate to should field slip" do
    login!(mary)
    visit field_slips_url
    click_on :field_slip_show.t
    assert_text :field_slip_index.t
    click_on "Back"
  end

  test "should update Field slip" do
    login!(mary)
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
    login!(mary)
    visit field_slip_url(@field_slip)
    click_on :field_slip_destroy.t, match: :first

    assert_text "Field slip was successfully destroyed"
  end
end
