# frozen_string_literal: true

require("test_helper")

module Tab::NameDescription
  class CollectionsTest < UnitTestCase
    def setup
      @description = name_descriptions(:agaricus_campestras_desc)
    end

    def test_form_new
      tabs = Tab::NameDescription::FormNew.new(
        description: @description
      ).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_form_edit_non_admin
      tabs = Tab::NameDescription::FormEdit.new(
        description: @description
      ).to_a

      # 2 Object::Return tabs: name + the description itself.
      assert_equal([Tab::Object::Return, Tab::Object::Return],
                   tabs.map(&:class))
      assert_equal(:show_object.t(type: :name), tabs[0].title)
    end

    def test_form_edit_admin
      tabs = Tab::NameDescription::FormEdit.new(
        description: @description, admin: true
      ).to_a

      assert_equal(
        [Tab::Object::Return, Tab::Object::Return,
         Tab::Description::AdjustPermissions],
        tabs.map(&:class)
      )
    end

    def test_form_permissions
      tabs = Tab::NameDescription::FormPermissions.new(
        description: @description
      ).to_a

      assert_equal([Tab::Object::Return, Tab::Object::Return],
                   tabs.map(&:class))
      assert_equal(:show_object.t(type: :name_description), tabs[1].title)
    end

    def test_version_actions
      tabs = Tab::NameDescription::VersionActions.new(
        description: @description, desc_title: "Foo"
      ).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
      assert_equal(
        :show_name_description.t(description: "Foo"),
        tabs.first.title
      )
    end
  end
end
