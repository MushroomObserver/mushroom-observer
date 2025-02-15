# frozen_string_literal: true

require("test_helper")

module Projects
  class AliasesControllerTest < FunctionalTestCase
    setup do
      @controller = Projects::AliasesController.new
      @project = projects(:eol_project)
      @project_alias = project_aliases(:one)
      @user = users(:rolf)
      login
    end

    def test_index_returns_all_project_aliases
      get(:index, params: { project_id: @project.id })
      assert_response(:success)
      assert_not_nil(assigns(:project_aliases))
    end

    def test_show_displays_the_requested_project_alias
      get(:show, params: { project_id: @project.id, id: @project_alias.id })
      assert_response(:success)
      assert_equal(@project_alias, assigns(:project_alias))
    end

    def test_new_displays_form_for_new_project_alias
      get(:new, params: { project_id: @project.id })
      assert_response(:success)
      assert_not_nil(assigns(:project_alias))
    end

    def test_edit_displays_form_to_edit_project_alias
      get(:edit, params: { project_id: @project.id, id: @project_alias.id })
      assert_response(:success)
      assert_equal(@project_alias, assigns(:project_alias))
    end

    def test_create_creates_new_project_alias_with_valid_location
      assert_difference("ProjectAlias.count") do
        post(:create, params: {
               project_id: @project.id,
               project_alias: {
                 name: "Walk 2",
                 project_id: @project.id,
                 target_type: "Location",
                 location_id: locations(:albion).id
               }
             })
      end

      assert_redirected_to(project_alias_path(
                             project_id: ProjectAlias.last.project_id,
                             id: ProjectAlias.last.id
                           ))
    end

    def test_create_creates_new_project_alias_with_valid_user
      assert_difference("ProjectAlias.count") do
        post(:create, params: {
               project_id: @project.id,
               project_alias: {
                 name: "RS2",
                 project_id: @project.id,
                 target_type: "User",
                 user_id: users(:rolf).id
               }
             })
      end

      assert_redirected_to(project_alias_path(
                             project_id: ProjectAlias.last.project_id,
                             id: ProjectAlias.last.id
                           ))
    end

    def test_create_renders_new_template_with_invalid_params
      project_id = @project.id
      post(:create, params: {
             project_id:,
             project_alias: { name: "", project_id: } # Invalid params
           })

      assert_response(:success)
      assert_template(:new)
    end

    def test_update_modifies_project_alias_with_valid_params
      project_id = @project.id
      patch(:update, params: {
              project_id:,
              id: @project_alias.id,
              project_alias: { name: "Updated Name", project_id: }
            })

      assert_redirected_to(project_alias_path(
                             project_id: @project_alias.project_id,
                             id: @project_alias.id
                           ))
      assert_equal("Updated Name", @project_alias.reload.name)
    end

    def test_update_renders_edit_template_with_invalid_params
      project_id = @project.id
      patch(:update, params: {
              project_id:,
              id: @project_alias.id,
              project_alias: { name: "", project_id: } # Invalid params
            })

      assert_response(:success)
      assert_template(:edit)
    end

    def test_destroy_removes_the_project_alias
      assert_difference("ProjectAlias.count", -1) do
        delete(:destroy,
               params: { project_id: @project.id, id: @project_alias.id })
      end

      assert_redirected_to(project_aliases_path(project_id: @project.id))
    end
  end
end
