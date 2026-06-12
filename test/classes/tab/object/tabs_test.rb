# frozen_string_literal: true

require("test_helper")

# Polymorphic Tab POROs that work with any object responding to
# `#type_tag`, `#show_link_args`, `#index_link_args`, and `#parent`.
module Tab::Object
  class TabsTest < UnitTestCase
    def setup
      @project = projects(:bolete_project)
      @herbarium = herbaria(:nybg_herbarium)
    end

    def test_return_default_title
      tab = Tab::Object::Return.new(object: @project)

      assert_equal(:cancel_and_show.t(type: :project), tab.title)
      assert_equal(@project.show_link_args, tab.path)
      assert_equal(@project, tab.model)
      assert_includes(tab.html_options[:class], "project_return_link")
    end

    def test_return_title_override
      tab = Tab::Object::Return.new(object: @project, title: "Custom")

      assert_equal("Custom", tab.title)
    end

    def test_show_default_title
      tab = Tab::Object::Show.new(object: @herbarium)

      assert_equal(:show_object.t(type: :herbarium), tab.title)
      assert_equal(@herbarium.show_link_args, tab.path)
      assert_equal(@herbarium, tab.model)
      assert_includes(tab.html_options[:class], "herbarium_link")
    end

    def test_show_title_override
      tab = Tab::Object::Show.new(object: @herbarium, title: "Other")

      assert_equal("Other", tab.title)
    end

    def test_show_parent
      desc = name_descriptions(:agaricus_campestras_desc)
      tab = Tab::Object::ShowParent.new(object: desc)

      assert_equal(:show_object.t(type: desc.parent.type_tag),
                   tab.title)
      assert_equal(desc.parent.show_link_args, tab.path)
      assert_includes(tab.html_options[:class],
                      "parent_#{desc.parent.type_tag}_link")
    end

    def test_index_default_title
      tab = Tab::Object::Index.new(object: @project)

      assert_equal(:list_objects.t(type: :project), tab.title)
      assert_equal(@project.index_link_args, tab.path)
      assert_includes(tab.html_options[:class], "projects_index_link")
    end

    def test_index_with_q_param
      tab = Tab::Object::Index.new(object: @project, q_param: "ABC")
      path = tab.path

      assert_equal("ABC", path[:q])
      # Original hash entries are preserved.
      @project.index_link_args.each do |k, v|
        assert_equal(v, path[k])
      end
    end
  end
end
