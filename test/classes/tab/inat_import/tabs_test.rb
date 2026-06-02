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

    def test_form_new
      tabs = Tab::InatImport::FormNew.new.to_a

      assert_equal([Tab::InatImport::Cancel], tabs.map(&:class))
    end
  end
end
