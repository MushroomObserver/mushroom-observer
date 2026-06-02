# frozen_string_literal: true

require("test_helper")

module Tab::ExternalLink
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @observation = observations(:detailed_unknown_obs)
      @link = external_links(:coprinus_comatus_obs_mycoportal_link)
    end

    def test_new
      tab = Tab::ExternalLink::New.new(observation: @observation)

      assert_equal(:show_observation_add_link.l, tab.title)
      assert_equal(routes.new_external_link_path(id: @observation.id), tab.path)
      assert_equal(:add, tab.html_options[:icon])
    end

    def test_edit
      tab = Tab::ExternalLink::Edit.new(link: @link)

      assert_equal(:EDIT.l, tab.title)
      assert_equal(routes.edit_external_link_path(id: @link), tab.path)
      assert_equal(:edit, tab.html_options[:icon])
      assert_equal(@link, tab.model)
    end
  end
end
