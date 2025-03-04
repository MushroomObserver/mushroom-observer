# frozen_string_literal: true

require "test_helper"

class VisualGroupsControllerTest < FunctionalTestCase
  setup do
    @visual_group = visual_groups(:visual_group_two)
    @visual_model = @visual_group.visual_model
  end

  test "should get index" do
    login
    get(:index, params: { visual_model_id: @visual_model.id })
    assert_response :success
  end

  test "should get new" do
    login
    get(:new, params: { visual_model_id: @visual_model.id })
    assert_response :success
  end

  test "should create visual_group" do
    login
    assert_difference("VisualGroup.count") do
      post(:create, params: {
             visual_model_id: @visual_model.id,
             visual_group: {
               name: @visual_group.name,
               approved: @visual_group.approved
             }
           })
    end
    assert_redirected_to visual_model_visual_groups_url(
      @visual_model, VisualGroup.last
    )
  end

  test "should not create visual_group" do
    login
    assert_no_difference("VisualGroup.count") do
      post(:create, params: {
             visual_model_id: @visual_model.id,
             visual_group: {
               name: "",
               approved: @visual_group.approved
             }
           })
    end
    assert_redirected_to new_visual_model_visual_group_url(@visual_model)
  end

  test "should not create visual_group due to tab" do
    login
    assert_no_difference("VisualGroup.count") do
      post(:create, params: {
             visual_model_id: @visual_model.id,
             visual_group: {
               name: "Name\twith\ttab",
               approved: @visual_group.approved
             }
           })
    end
    assert_redirected_to new_visual_model_visual_group_url(@visual_model)
  end

  test "should show visual_group" do
    login
    get(:show, params: {
          id: @visual_group.id,
          visual_model_id: @visual_model.id
        })
    assert_response :success
  end

  test "should show visual_group with filter" do
    login
    get(:show, params: {
          id: @visual_group.id,
          filter: "Agaricus",
          visual_model_id: @visual_model.id
        })
    assert_response :success
  end

  test "should get edit" do
    login
    get(:edit, params: { id: @visual_group.id })
    assert_response :success
    assert_match(image_path(observations(:peltigera_mary_obs).thumb_image.id),
                 response.body)
  end

  test "should get edit page with excluded images" do
    login
    get(:edit, params: { id: @visual_group.id, status: "excluded" })
    assert_response :success
  end

  test "should update visual_group" do
    login
    patch(:update, params: {
            id: @visual_group.id,
            visual_group: {
              name: @visual_group.name,
              approved: @visual_group.approved
            }
          })
    assert_redirected_to visual_model_visual_groups_url(@visual_model,
                                                        @visual_group)
  end

  test "should not update visual_group" do
    login
    patch(:update, params: {
            id: @visual_group.id,
            visual_group: {
              name: "",
              approved: @visual_group.approved
            }
          })
    assert_redirected_to edit_visual_group_url(@visual_group)
  end

  test "should destroy visual_group" do
    login
    assert_difference("VisualGroup.count", -1) do
      delete(:destroy, params: { id: @visual_group.id })
    end
    assert_redirected_to visual_model_visual_groups_url(@visual_model)
  end
end
