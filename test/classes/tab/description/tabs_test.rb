# frozen_string_literal: true

require("test_helper")

# Covers Tab::Description::* single Tab POROs. Each test pins
# title / path (via route helpers) / html_options.
module Tab::Description
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @name = names(:coprinus_comatus)
      @location = locations(:albion)
      @name_desc = name_descriptions(:draft_coprinus_comatus)
      @location_desc = location_descriptions(:albion_desc)
    end

    def test_create_for_name
      tab = Tab::Description::Create.new(parent: @name)

      assert_equal(:show_name_create_description.t, tab.title)
      assert_equal(routes.new_name_description_path(name_id: @name.id),
                   tab.path)
      assert_equal(:add, tab.html_options[:icon])
      assert_equal(NameDescription, tab.model)
    end

    def test_create_for_location
      tab = Tab::Description::Create.new(parent: @location)

      assert_equal(routes.new_location_description_path(
                     location_id: @location.id
                   ), tab.path)
      assert_equal(LocationDescription, tab.model)
    end

    def test_edit_name_description
      tab = Tab::Description::Edit.new(description: @name_desc)

      assert_equal(:show_description_edit.t, tab.title)
      assert_equal(routes.edit_name_description_path(@name_desc.id), tab.path)
      assert_equal(:edit, tab.html_options[:icon])
      assert_equal(@name_desc, tab.model)
    end

    def test_edit_location_description
      tab = Tab::Description::Edit.new(description: @location_desc)

      assert_equal(
        routes.edit_location_description_path(@location_desc.id), tab.path
      )
    end

    def test_clone
      tab = Tab::Description::Clone.new(description: @name_desc)

      assert_equal(:show_description_clone.t, tab.title)
      assert_equal(routes.new_name_description_path(
                     clone: @name_desc.id, name_id: @name_desc.parent_id
                   ), tab.path)
      assert_equal(:show_description_clone_help.l, tab.html_options[:help])
      assert_equal(:clone, tab.html_options[:icon])
    end

    def test_merge
      tab = Tab::Description::Merge.new(description: @name_desc)

      assert_equal(:show_description_merge.t, tab.title)
      assert_equal(routes.new_merge_name_description_path(@name_desc.id),
                   tab.path)
      assert_equal(:merge, tab.html_options[:icon])
    end

    def test_move
      tab = Tab::Description::Move.new(description: @location_desc)

      assert_equal(:show_description_move.t, tab.title)
      assert_equal(routes.new_move_location_description_path(@location_desc.id),
                   tab.path)
      assert_equal(:show_description_move_help.l(parent: "location"),
                   tab.html_options[:help])
    end

    def test_adjust_permissions
      tab = Tab::Description::AdjustPermissions.new(description: @name_desc)

      assert_equal(:show_description_adjust_permissions.t, tab.title)
      assert_equal(
        routes.edit_permissions_name_description_path(@name_desc.id),
        tab.path
      )
      assert_equal(:adjust, tab.html_options[:icon])
    end

    def test_make_default
      tab = Tab::Description::MakeDefault.new(description: @name_desc)

      assert_equal(:show_description_make_default.t, tab.title)
      assert_equal(
        routes.make_default_name_description_path(@name_desc.id), tab.path
      )
      assert_equal(:put, tab.html_options[:button])
      assert_equal(:make_default, tab.html_options[:icon])
    end

    def test_project
      project_desc = name_descriptions(:draft_coprinus_comatus)
      tab = Tab::Description::Project.new(description: project_desc)

      assert_equal(:show_object.t(type: :project), tab.title)
      assert_equal(project_desc.source_object.show_link_args, tab.path)
      assert_equal(:project, tab.html_options[:icon])
    end

    def test_publish_draft
      tab = Tab::Description::PublishDraft.new(description: @name_desc)

      assert_equal(:show_description_publish.t, tab.title)
      assert_equal(routes.publish_name_description_path(@name_desc.id),
                   tab.path)
      assert_equal(:put, tab.html_options[:button])
      assert_equal(:publish, tab.html_options[:icon])
    end

    def test_new_for_project
      project = projects(:eol_project)
      tab = Tab::Description::NewForProject.new(
        parent: @name, project: project
      )

      assert_equal(project.title, tab.title)
      assert_equal(routes.new_name_description_path(
                     project: project.id, source: "project",
                     name_id: @name.id
                   ), tab.path)
      assert_equal(NameDescription, tab.model)
    end
  end
end
