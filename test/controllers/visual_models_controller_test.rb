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

  # test "should create visual_model" do
  #   assert_difference('VisualModel.count') do
  #     post visual_models_url, params: { visual_model: {
  # name: @visual_model.name,
  # reviewed: @visual_model.reviewed } }
  #   end

  #   assert_redirected_to visual_model_url(VisualModel.last)
  # end

  test "should show visual_model" do
    login
    get(:show, params: { id: visual_models(:visual_model_one).id })
    assert_response :success
  end

  # test "should get edit" do
  #   get edit_visual_model_url(@visual_model)
  #   assert_response :success
  # end

  # test "should update visual_model" do
  #   patch visual_model_url(@visual_model), params: { visual_model:
  # { name: @visual_model.name,
  # reviewed: @visual_model.reviewed } }
  #   assert_redirected_to visual_model_url(@visual_model)
  # end

  # test "should destroy visual_model" do
  #   assert_difference('VisualModel.count', -1) do
  #     delete visual_model_url(@visual_model)
  #   end

  #   assert_redirected_to visual_models_url
  # end
end
