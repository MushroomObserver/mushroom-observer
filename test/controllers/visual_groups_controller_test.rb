# frozen_string_literal: true

require("test_helper")

class VisualGroupsControllerTest < FunctionalTestCase
  setup do
    @visual_group = visual_groups(:visual_group_two)
    @visual_model = @visual_group.visual_model
  end

  def test_should_get_index
    login
    get(:index, params: { visual_model_id: @visual_model.id })
    assert_response(:success)
  end

  def test_should_get_new
    login
    get(:new, params: { visual_model_id: @visual_model.id })
    assert_response(:success)
  end

  def test_should_create_visual_group
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
    assert_redirected_to(visual_model_visual_groups_url(
                           @visual_model, VisualGroup.last
                         ))
  end

  def test_should_not_create_visual_group
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
    assert_redirected_to(new_visual_model_visual_group_url(@visual_model))
  end

  def test_should_not_create_visual_group_due_to_tab
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
    assert_redirected_to(new_visual_model_visual_group_url(@visual_model))
  end

  def test_should_show_visual_group
    login
    get(:show, params: {
          id: @visual_group.id,
          visual_model_id: @visual_model.id
        })
    assert_response(:success)
  end

  def test_should_show_visual_group_with_filter
    login
    get(:show, params: {
          id: @visual_group.id,
          filter: "Agaricus",
          visual_model_id: @visual_model.id
        })
    assert_response(:success)
  end

  def test_should_get_edit
    login
    get(:edit, params: { id: @visual_group.id })
    assert_response(:success)
    assert_match(image_path(observations(:peltigera_mary_obs).thumb_image.id),
                 response.body)
  end

  def test_should_get_edit_page_with_excluded_images
    login
    get(:edit, params: { id: @visual_group.id, status: "excluded" })
    assert_response(:success)
  end

  def test_should_update_visual_group
    login
    patch(:update, params: {
            id: @visual_group.id,
            visual_group: {
              name: @visual_group.name,
              approved: @visual_group.approved
            }
          })
    assert_redirected_to(visual_model_visual_groups_url(@visual_model,
                                                        @visual_group))
  end

  def test_should_not_update_visual_group
    login
    patch(:update, params: {
            id: @visual_group.id,
            visual_group: {
              name: "",
              approved: @visual_group.approved
            }
          })
    assert_redirected_to(edit_visual_group_url(@visual_group))
  end

  def test_should_destroy_visual_group
    login
    assert_difference("VisualGroup.count", -1) do
      delete(:destroy, params: { id: @visual_group.id })
    end
    assert_redirected_to(visual_model_visual_groups_url(@visual_model))
  end
end
