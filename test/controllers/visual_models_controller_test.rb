# frozen_string_literal: true

require "test_helper"

class VisualModelsControllerTest < FunctionalTestCase
  setup do
    @visual_model = visual_models(:visual_model_one)
  end

  test "should get index" do
    login
    get(:index)
    assert_response :success
  end

  test "should get new" do
    login
    get(:new)
    assert_response :success
  end

  test "should create visual_model" do
    login
    assert_difference("VisualModel.count") do
      post(:create, params: { visual_model: {
             name: @visual_model.name
           } })
    end

    assert_redirected_to visual_model_url(VisualModel.last)
  end

  test "should not create visual_model" do
    login
    assert_no_difference("VisualModel.count") do
      post(:create, params: { visual_model: {
             name: ""
           } })
    end

    assert_redirected_to new_visual_model_url
  end

  test "should not create visual_model due to tab" do
    login
    assert_no_difference("VisualModel.count") do
      post(:create, params: { visual_model: {
             name: "Name\twith\ttab"
           } })
    end

    assert_redirected_to new_visual_model_url
  end

  test "should show visual_model" do
    login
    get(:show, params: { id: visual_models(:visual_model_one).id })
    assert_response :success
  end

  test "should show visual_model as json" do
    login
    get(:show, params: { format: :json,
                         id: visual_models(:visual_model_one).id })
    assert_response :success
  end

  test "should get edit" do
    login
    get(:edit, params: { id: @visual_model.id })
    assert_response :success
  end

  test "should update visual_model" do
    login
    patch(:update, params: {
            id: @visual_model.id,
            visual_model: { name: @visual_model.name }
          })
    assert_redirected_to visual_model_url(@visual_model)
  end

  test "should not update visual_model" do
    login
    patch(:update, params: {
            id: @visual_model.id,
            visual_model: { name: "" }
          })
    assert_redirected_to edit_visual_model_url(@visual_model)
  end

  test "should destroy visual_model" do
    login
    assert_difference("VisualModel.count", -1) do
      delete(:destroy, params: { id: @visual_model.id })
    end
    assert_redirected_to visual_models_url
  end
end
