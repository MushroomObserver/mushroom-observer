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

    test "index returns all project aliases" do
      get(:index, params: { project_id: @project.id })
      assert_response(:success)
      assert_not_nil(assigns(:project_aliases))
    end

    test "index returns json when requested" do
      get(:index, params: { project_id: @project.id }, format: :json)
      assert_response(:success)
      assert_equal("application/json; charset=utf-8", response.content_type)
    end

    test "show displays the requested project alias" do
      get(:show, params: { project_id: @project.id, id: @project_alias.id })
      assert_response(:success)
      assert_equal(@project_alias, assigns(:project_alias))
    end

    test "show returns json when requested" do
      get(:show, params: { project_id: @project.id, id: @project_alias.id },
                 format: :json)
      assert_response(:success)
      assert_equal("application/json; charset=utf-8", response.content_type)
    end

    test "new displays form for new project alias" do
      get(:new, params: { project_id: @project.id })
      assert_response(:success)
      assert_not_nil(assigns(:project_alias))
    end

    test "edit displays form to edit project alias" do
      get(:edit, params: { project_id: @project.id, id: @project_alias.id })
      assert_response(:success)
      assert_equal(@project_alias, assigns(:project_alias))
    end

    test "create creates new project alias with valid location" do
      assert_difference("ProjectAlias.count") do
        post(:create, params: {
               project_id: @project.id,
               project_alias: {
                 name: "Walk 1",
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

    test "create creates new project alias with valid user" do
      assert_difference("ProjectAlias.count") do
        post(:create, params: {
               project_id: @project.id,
               project_alias: {
                 name: "RS",
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

    test "create renders new template with invalid params" do
      post(:create, params: {
             project_id: @project.id,
             project_alias: { name: "" }  # Invalid params
           })

      assert_response(:success)
      assert_template(:new)
    end

    test "create returns error json with invalid params" do
      post(:create, params: {
             project_id: @project.id,
             project_alias: { name: "" }  # Invalid params
           }, format: :json)

      assert_equal(response.status, 422)
      assert_equal("application/json; charset=utf-8", response.content_type)
    end

    test "update modifies project alias with valid params" do
      patch(:update, params: {
              project_id: @project.id,
              id: @project_alias.id,
              project_alias: { name: "Updated Name" }
            })

      assert_redirected_to(project_alias_path(
                             project_id: @project_alias.project_id,
                             id: @project_alias.id
                           ))
      assert_equal("Updated Name", @project_alias.reload.name)
    end

    test "update returns json when requested" do
      patch(:update, params: {
              project_id: @project.id,
              id: @project_alias.id,
              project_alias: { name: "Updated Name" }
            }, format: :json)

      assert_response(:success)
      assert_equal("application/json; charset=utf-8", response.content_type)
    end

    test "update renders edit template with invalid params" do
      patch(:update, params: {
              project_id: @project.id,
              id: @project_alias.id,
              project_alias: { name: "" }  # Invalid params
            })

      assert_response(:success)
      assert_template(:edit)
    end

    test "update returns error json with invalid params" do
      patch(:update, params: {
              project_id: @project.id,
              id: @project_alias.id,
              project_alias: { name: "" }  # Invalid params
            }, format: :json)

      assert_equal(response.status, 422)
      assert_equal("application/json; charset=utf-8", response.content_type)
    end

    test "destroy removes the project alias" do
      assert_difference("ProjectAlias.count", -1) do
        delete(:destroy,
               params: { project_id: @project.id, id: @project_alias.id })
      end

      assert_redirected_to(project_aliases_path(project_id: @project.id))
    end

    test "destroy returns no content when json requested" do
      delete(:destroy, params: {
               project_id: @project.id,
               id: @project_alias.id
             }, format: :json)

      assert_equal(response.status, 204)
    end
  end
end
