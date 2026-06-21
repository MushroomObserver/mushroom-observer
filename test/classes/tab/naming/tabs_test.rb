# frozen_string_literal: true

require("test_helper")

module Tab::Naming
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @naming = namings(:coprinus_comatus_naming)
    end

    def test_new
      tab = Tab::Naming::New.new(
        observation_id: 42, text: "Propose", context: "blank"
      )

      assert_equal("Propose", tab.title)
      expected = routes.new_observation_naming_path(
        observation_id: 42, context: "blank"
      )
      assert_equal(expected, tab.path)
      assert_includes(tab.html_options[:class], "propose-naming-link")
      assert_equal(:add, tab.html_options[:icon])
      assert_equal(Naming, tab.model)
    end

    def test_edit
      tab = Tab::Naming::Edit.new(naming: @naming)

      assert_equal(:EDIT.l, tab.title)
      assert_equal(
        routes.edit_observation_naming_path(
          observation_id: @naming.observation_id, id: @naming.id
        ),
        tab.path
      )
      assert_equal(:edit, tab.html_options[:icon])
      assert_equal(@naming, tab.model)
    end
  end
end
