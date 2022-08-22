require "application_system_test_case"

class VisualGroupsTest < ApplicationSystemTestCase
  setup do
    @visual_group = visual_groups(:one)
  end

  test "visiting the index" do
    visit visual_groups_url
    assert_selector "h1", text: "Visual Groups"
  end

  test "creating a Visual group" do
    visit visual_groups_url
    click_on "New Visual Group"

    fill_in "Name", with: @visual_group.name_id
    check "Reviewed" if @visual_group.reviewed
    click_on "Create Visual group"

    assert_text "Visual group was successfully created"
    click_on "Back"
  end

  test "updating a Visual group" do
    visit visual_groups_url
    click_on "Edit", match: :first

    fill_in "Name", with: @visual_group.name_id
    check "Reviewed" if @visual_group.reviewed
    click_on "Update Visual group"

    assert_text "Visual group was successfully updated"
    click_on "Back"
  end

  test "destroying a Visual group" do
    visit visual_groups_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Visual group was successfully destroyed"
  end
end
