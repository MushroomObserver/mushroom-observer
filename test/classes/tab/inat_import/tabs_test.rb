# frozen_string_literal: true

require("test_helper")

module Tab::InatImport
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_cancel
      tab = Tab::InatImport::Cancel.new

      assert_equal(:cancel_and_create.t(type: :OBSERVATION), tab.title)
      assert_equal(routes.new_observation_path, tab.path)
    end

    def test_index
      tab = Tab::InatImport::Index.new

      assert_equal(:INAT_IMPORTS.t, tab.title)
      assert_equal(routes.inat_imports_path, tab.path)
    end

    def test_form_new_without_prior_imports
      tabs = Tab::InatImport::FormNew.new.to_a

      assert_equal([Tab::InatImport::Cancel], tabs.map(&:class))
    end

    def test_form_new_with_prior_imports
      tabs = Tab::InatImport::FormNew.new(has_prior_imports: true).to_a

      assert_equal([Tab::InatImport::Cancel, Tab::InatImport::Index],
                   tabs.map(&:class))
    end
  end
end
