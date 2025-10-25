# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::ExternalLinks class to be included in QueryTest
class Query::ExternalLinksTest < UnitTestCase
  include QueryExtensions

  def test_external_link_all
    assert_query(ExternalLink.order_by_default, :ExternalLink)
  end

  def test_external_link_order_by_url
    expects = ExternalLink.order_by(:url)
    assert_query(expects, :ExternalLink, order_by: :url)
  end

  def test_external_link_id_in_set
    set = ExternalLink.order(id: :asc).last(2).pluck(:id)
    scope = ExternalLink.id_in_set(set)
    assert_query_scope(set, scope, :ExternalLink, id_in_set: set)
  end

  def test_external_link_by_users
    scope = ExternalLink.by_users(users(:mary)).order_by_default
    assert_query(scope, :ExternalLink, by_users: users(:mary))
    assert_query(ExternalLink.by_users(users(:dick)).order_by_default,
                 :ExternalLink, by_users: users(:dick))
    assert_query([], :ExternalLink, by_users: users(:zero_user))
  end

  def test_external_link_observations
    obs = observations(:coprinus_comatus_obs)
    expects = obs.external_links.sort_by(&:url)
    scope = ExternalLink.observations(obs).order_by_default
    assert_query_scope(expects, scope, :ExternalLink, observations: obs)
    obs = observations(:detailed_unknown_obs)
    assert_query([], :ExternalLink, observations: obs)
  end

  def test_external_link_external_sites
    sites = [external_sites(:mycoportal),
             external_sites(:inaturalist)]
    sites.each do |site|
      expects = site.external_links.sort_by(&:url)
      scope = ExternalLink.external_sites(site).order_by_default
      assert_query_scope(expects, scope, :ExternalLink, external_sites: site)
    end
  end

  def test_external_link_url_has
    site = external_sites(:inaturalist)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, url_has: "inaturalist.org")
    expects = ExternalLink.url_has("inaturalist.org").order_by_default
    assert_query(expects, :ExternalLink, url_has: "inaturalist.org")
  end
end
