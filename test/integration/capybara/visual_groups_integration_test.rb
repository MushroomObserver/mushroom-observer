# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for visual group form submission
class VisualGroupsIntegrationTest < CapybaraIntegrationTestCase
  def test_create_visual_group
    # Login as admin
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click
    visual_model = visual_models(:visual_model_one)

    # Visit the new visual group page
    visit(new_visual_model_visual_group_path(visual_model))
    assert_selector("body.visual_groups__new")

    # Fill in the form with valid data
    fill_in("visual_group_name", with: "Test Visual Group")

    # Submit the form
    within("#visual_group_form") do
      click_commit
    end

    # Verify successful creation (redirects to index showing the new group)
    assert_selector("body.visual_groups__index")

    # Verify database effect
    group = VisualGroup.find_by(name: "Test Visual Group")
    assert(group, "Visual group should have been created")
    assert_equal(visual_model.id, group.visual_model_id)
  end

  def test_edit_visual_group
    # Login as admin
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click
    group = visual_groups(:visual_group_one)

    # Visit the edit visual group page
    visit(edit_visual_group_path(group))
    assert_selector("body.visual_groups__edit")

    # Update the form with valid data
    fill_in("visual_group_name", with: "Updated Visual Group Name")

    # Submit the form
    within("#visual_group_form") do
      click_commit
    end

    # Verify successful update (redirects to index)
    assert_selector("body.visual_groups__index")

    # Verify database effect
    group.reload
    assert_equal("Updated Visual Group Name", group.name)
  end
end
