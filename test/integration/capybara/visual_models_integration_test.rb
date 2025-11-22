# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for visual model form submission
class VisualModelsIntegrationTest < CapybaraIntegrationTestCase
  def test_create_visual_model
    # Login as admin
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click

    # Visit the new visual model page
    visit(new_visual_model_path)
    assert_selector("body.visual_models__new")

    # Fill in the form with valid data
    fill_in("visual_model_name", with: "Test Visual Model")

    # Submit the form
    within("#visual_model_form") do
      click_commit
    end

    # Verify successful creation
    assert_selector("body.visual_models__show")

    # Verify database effect
    model = VisualModel.find_by(name: "Test Visual Model")
    assert(model, "Visual model should have been created")
  end

  def test_edit_visual_model
    # Login as admin
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click
    model = visual_models(:visual_model_one)

    # Visit the edit visual model page
    visit(edit_visual_model_path(model))
    assert_selector("body.visual_models__edit")

    # Update the form with valid data
    fill_in("visual_model_name", with: "Updated Visual Model Name")

    # Submit the form
    within("#visual_model_form") do
      click_commit
    end

    # Verify successful update
    assert_selector("body.visual_models__show")

    # Verify database effect
    model.reload
    assert_equal("Updated Visual Model Name", model.name)
  end
end
