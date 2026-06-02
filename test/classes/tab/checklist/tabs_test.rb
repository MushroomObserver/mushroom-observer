# frozen_string_literal: true

require("test_helper")

# Tab::Checklist::SiteList is split out of the rest of the checklist-
# domain conversion (deferred to the users+account batch, where the
# user-checklist and species_list-checklist paths can be converted
# together) because the info/site_stats action-nav composes it.
module Tab::Checklist
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_site_list
      tab = Tab::Checklist::SiteList.new

      assert_equal(:site_stats_observed_taxa.t, tab.title)
      assert_equal(routes.checklist_path, tab.path)
    end
  end
end
