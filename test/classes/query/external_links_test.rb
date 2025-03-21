# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::ExternalLinks class to be included in QueryTest
class Query::ExternalLinksTest < UnitTestCase
  include QueryExtensions

  def test_external_link_all
    assert_query(ExternalLink.index_order, :ExternalLink)
  end

  def test_external_link_id_in_set
    set = ExternalLink.order(id: :asc).last(2).pluck(:id)
    scope = ExternalLink.id_in_set(set)
    assert_query_scope(set, scope, :ExternalLink, id_in_set: set)
  end

  def test_external_link_by_users
    assert_query(ExternalLink.by_users(users(:mary)).index_order,
                 :ExternalLink, by_users: users(:mary))
    assert_query([], :ExternalLink, by_users: users(:dick))
  end

  def test_external_link_observations
    obs = observations(:coprinus_comatus_obs)
    expects = obs.external_links.sort_by(&:url)
    scope = ExternalLink.observations(obs).index_order
    assert_query_scope(expects, scope, :ExternalLink, observations: obs)
    obs = observations(:detailed_unknown_obs)
    assert_query([], :ExternalLink, observations: obs)
  end

  def test_external_link_external_sites
    site = external_sites(:mycoportal)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, external_sites: site)
    site = external_sites(:inaturalist)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, external_sites: site)
    expects = ExternalLink.external_sites(site).index_order
    assert_query(expects, :ExternalLink, external_sites: site)
  end

  def test_external_link_url_has
    site = external_sites(:inaturalist)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, url_has: "inaturalist.org")
    expects = ExternalLink.url_has("inaturalist.org").index_order
    assert_query(expects, :ExternalLink, url_has: "inaturalist.org")
  end
end
