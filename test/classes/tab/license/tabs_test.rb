# frozen_string_literal: true

require("test_helper")

module Tab::License
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_index
      tab = Tab::License::Index.new

      assert_equal(:index_object.t(type: :license), tab.title)
      assert_equal(routes.licenses_path, tab.path)
      assert_equal(License, tab.model)
    end

    def test_new
      tab = Tab::License::New.new

      assert_equal(:create_object.t(type: :license), tab.title)
      assert_equal(routes.new_license_path, tab.path)
      assert_equal(License, tab.model)
    end
  end

  class CollectionsTest < UnitTestCase
    def setup
      @license = licenses(:ccbync)
    end

    def test_index_actions
      tabs = Tab::License::IndexActions.new.to_a

      assert_equal([Tab::License::New], tabs.map(&:class))
    end

    def test_form_new
      tabs = Tab::License::FormNew.new.to_a

      assert_equal([Tab::License::Index], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::License::FormEdit.new(license: @license).to_a

      assert_equal(
        [Tab::Object::Return, Tab::License::Index],
        tabs.map(&:class)
      )
    end
  end
end
