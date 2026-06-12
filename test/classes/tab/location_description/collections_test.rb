# frozen_string_literal: true

require("test_helper")

module Tab::LocationDescription
  class CollectionsTest < UnitTestCase
    def setup
      @description = location_descriptions(:albion_desc)
    end

    def test_form_new
      tabs = Tab::LocationDescription::FormNew.new(
        description: @description
      ).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::LocationDescription::FormEdit.new(
        description: @description
      ).to_a

      assert_equal([Tab::Object::Return, Tab::Object::Return],
                   tabs.map(&:class))
    end

    def test_form_permissions
      tabs = Tab::LocationDescription::FormPermissions.new(
        description: @description
      ).to_a

      assert_equal([Tab::Object::Return, Tab::Object::Return],
                   tabs.map(&:class))
      # Second tab has the title override for "location_description".
      assert_equal(
        :show_object.t(type: :location_description),
        tabs[1].title
      )
    end

    def test_version_actions
      tabs = Tab::LocationDescription::VersionActions.new(
        description: @description, desc_title: "Foo"
      ).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
      assert_equal(
        :show_location_description.t(description: "Foo"),
        tabs.first.title
      )
    end
  end
end
