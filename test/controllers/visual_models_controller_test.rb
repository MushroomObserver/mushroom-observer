# frozen_string_literal: true

require("test_helper")

class VisualModelsControllerTest < FunctionalTestCase
  setup do
    @visual_model = visual_models(:visual_model_one)
  end

  def test_should_get_index
    login
    get(:index)
    assert_response(:success)
  end

  def test_should_get_new
    login
    get(:new)
    assert_response(:success)
  end

  def test_should_create_visual_model
    login
    assert_difference("VisualModel.count") do
      post(:create, params: { visual_model: {
             name: @visual_model.name
           } })
    end

    assert_redirected_to(visual_model_url(VisualModel.last))
  end

  def test_should_not_create_visual_model
    login
    assert_no_difference("VisualModel.count") do
      post(:create, params: { visual_model: {
             name: ""
           } })
    end

    assert_redirected_to(new_visual_model_url)
  end

  def test_should_not_create_visual_model_due_to_tab
    login
    assert_no_difference("VisualModel.count") do
      post(:create, params: { visual_model: {
             name: "Name\twith\ttab"
           } })
    end

    assert_redirected_to(new_visual_model_url)
  end

  def test_should_show_visual_model
    login
    get(:show, params: { id: visual_models(:visual_model_one).id })
    assert_response(:success)
  end

  def test_should_show_visual_model_as_json
    login
    get(:show, params: { format: :json,
                         id: visual_models(:visual_model_one).id })
    assert_response(:success)
  end

  def test_should_get_edit
    login
    get(:edit, params: { id: @visual_model.id })
    assert_response(:success)
  end

  def test_should_update_visual_model
    login
    patch(:update, params: {
            id: @visual_model.id,
            visual_model: { name: @visual_model.name }
          })
    assert_redirected_to(visual_model_url(@visual_model))
  end

  def test_should_not_update_visual_model
    login
    patch(:update, params: {
            id: @visual_model.id,
            visual_model: { name: "" }
          })
    assert_redirected_to(edit_visual_model_url(@visual_model))
  end

  def test_should_destroy_visual_model
    login
    assert_difference("VisualModel.count", -1) do
      delete(:destroy, params: { id: @visual_model.id })
    end
    assert_redirected_to(visual_models_url)
  end
end
