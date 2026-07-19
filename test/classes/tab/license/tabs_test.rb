# frozen_string_literal: true

require("test_helper")

module Tab::License
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @license = licenses(:ccbync)
    end

    def test_index
      tab = Tab::License::Index.new

      assert_equal(:index_license.t, tab.title)
      assert_equal(routes.licenses_path, tab.path)
      assert_equal(License, tab.model)
    end

    def test_new
      tab = Tab::License::New.new

      assert_equal(:create_license_title.t, tab.title)
      assert_equal(routes.new_license_path, tab.path)
      assert_equal(License, tab.model)
    end

    def test_edit
      tab = Tab::License::Edit.new(license: @license)

      assert_equal(:edit.ti, tab.title)
      assert_equal(routes.edit_license_path(@license.id), tab.path)
      assert_equal(@license, tab.model)
    end

    def test_destroy
      tab = Tab::License::Destroy.new(license: @license)

      assert_equal(:destroy.ti, tab.title)
      assert_equal(@license, tab.path)
      assert_equal(:destroy, tab.html_options[:button])
      assert_equal(@license, tab.model)
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

    def test_show_actions_in_use
      @license.define_singleton_method(:in_use?) { true }
      tabs = Tab::License::ShowActions.new(license: @license).to_a

      assert_equal(
        [Tab::License::Index, Tab::License::New, Tab::License::Edit],
        tabs.map(&:class)
      )
    end

    def test_show_actions_not_in_use
      @license.define_singleton_method(:in_use?) { false }
      tabs = Tab::License::ShowActions.new(license: @license).to_a

      assert_equal(
        [Tab::License::Index, Tab::License::New, Tab::License::Edit,
         Tab::License::Destroy],
        tabs.map(&:class)
      )
    end
  end
end
