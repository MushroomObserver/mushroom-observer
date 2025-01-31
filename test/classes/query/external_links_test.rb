# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::ExternalLinks class to be included in QueryTest
class Query::ExternalLinksTest < UnitTestCase
  include QueryExtensions

  def test_external_link_all
    assert_query(ExternalLink.all.sort_by(&:url), :ExternalLink)
    assert_query(ExternalLink.where(user: users(:mary)).sort_by(&:url),
                 :ExternalLink, users: users(:mary))
    assert_query([], :ExternalLink, users: users(:dick))
    obs = observations(:coprinus_comatus_obs)
    assert_query(obs.external_links.sort_by(&:url),
                 :ExternalLink, observations: obs)
    obs = observations(:detailed_unknown_obs)
    assert_query([], :ExternalLink, observations: obs)
    site = external_sites(:mycoportal)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, external_sites: site)
    site = external_sites(:inaturalist)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, external_sites: site)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, url: "iNaturalist")
  end
end
