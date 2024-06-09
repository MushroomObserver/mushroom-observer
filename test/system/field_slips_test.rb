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
    find(:xpath, '//*[@id="field_slips"]/a[1]').click
    assert_text :field_slip_index.t
  end

  test "should update field slip" do
    login!(mary)
    visit field_slip_url(@field_slip)
    click_on :field_slip_edit.t, match: :first

    fill_in "field_slip_code", with: @field_slip.code
    select(@field_slip.project.title, from: :PROJECT.t)
    click_on :field_slip_keep_obs.t

    assert_text :field_slip_updated.t
  end

  test "should destroy field slip" do
    login!(mary)
    visit field_slip_url(@field_slip)
    click_on :DESTROY.t, match: :first

    assert_text :field_slip_destroyed.t
  end
end
